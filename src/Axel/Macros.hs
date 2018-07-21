{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}

module Axel.Macros where

import Axel.AST
  ( Identifier
  , MacroDefinition
  , Statement(SDataDeclaration, SFunctionDefinition, SLanguagePragma,
          SMacroDefinition, SModuleDeclaration, SQualifiedImport,
          SRestrictedImport, STopLevel, STypeSynonym, STypeclassInstance,
          SUnrestrictedImport)
  , ToHaskell(toHaskell)
  , definitions
  , name
  , removeDefinitionsByName
  , statements
  )
import Axel.Denormalize (denormalizeExpression, denormalizeStatement)
import Axel.Error (Error(MacroError), fatal)
import Axel.Eval (evalMacro)
import Axel.Normalize (normalizeStatement)
import qualified Axel.Parse as Parse
  ( Expression(LiteralChar, LiteralInt, LiteralString, SExpression,
           Symbol)
  , parseMultiple
  )
import Axel.Utils.Display (Delimiter(Newlines), delimit, isOperator)
import Axel.Utils.Function (uncurry3)
import Axel.Utils.Recursion
  ( Recursive(bottomUpFmap, bottomUpTraverse)
  , exhaustM
  )
import Axel.Utils.Resources (readDataFile)
import Axel.Utils.String (replace)

import Control.Lens.Operators ((%~), (^.))
import Control.Lens.Tuple (_1, _2)
import Control.Monad (foldM)
import Control.Monad.Except (MonadError, catchError, throwError)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Trans.Control (MonadBaseControl)

import Data.Function ((&))
import Data.List (foldl')
import Data.Semigroup ((<>))

getAstDefinition :: IO String
getAstDefinition = readDataFile "autogenerated/macros/AST.hs"

generateMacroProgram ::
     (MonadBaseControl IO m, MonadError Error m, MonadIO m)
  => MacroDefinition
  -> [Statement]
  -> [Parse.Expression]
  -> m (String, String, String)
generateMacroProgram macroDefinition environment applicationArguments = do
  astDefinition <- liftIO getAstDefinition
  scaffold <- liftIO getScaffold
  macroDefinitionAndEnvironment <-
    (<>) <$> liftIO getMacroDefinitionAndEnvironmentHeader <*>
    getMacroDefinitionAndEnvironmentFooter
  pure (astDefinition, scaffold, macroDefinitionAndEnvironment)
  where
    getMacroDefinitionAndEnvironmentHeader =
      readDataFile "macros/MacroDefinitionAndEnvironmentHeader.hs"
    getMacroDefinitionAndEnvironmentFooter = do
      hygenicMacroDefinition <-
        replaceName
          (macroDefinition ^. name)
          newMacroName
          (SMacroDefinition macroDefinition)
      let source =
            delimit Newlines $
            map toHaskell (environment <> [hygenicMacroDefinition])
      pure source
    getScaffold =
      let insertApplicationArguments =
            let applicationArgumentsPlaceholder = "%%%ARGUMENTS%%%"
            in replace
                 applicationArgumentsPlaceholder
                 (show applicationArguments)
          insertDefinitionName =
            let definitionNamePlaceholder = "%%%MACRO_NAME%%%"
            in replace definitionNamePlaceholder newMacroName
      in insertApplicationArguments . insertDefinitionName <$>
         readDataFile "macros/Scaffold.hs"
    newMacroName =
      (macroDefinition ^. name) ++
      if isOperator (macroDefinition ^. name)
        then "%%%%%%%%%%"
        else "_AXEL_AUTOGENERATED_MACRO_DEFINITION"

extractIndependentStatements :: [Parse.Expression] -> [Parse.Expression]
extractIndependentStatements stmts =
  let candidateMacroDefinitions = filter isMacroDefinition stmts
  in filter (not . isDependentOnAny candidateMacroDefinitions) stmts
  where
    isMacroDefinition (Parse.SExpression (Parse.Symbol "defmacro":_)) = True
    isMacroDefinition _ = False
    macroNameFromDefinition (Parse.SExpression (Parse.Symbol "defmacro":Parse.Symbol macroName:_)) =
      macroName
    macroNameFromDefinition _ =
      error
        "macroNameFromDefinition should only be called with a valid macro definition!"
    isDependentOn macroDefinition (Parse.SExpression (Parse.Symbol symbol:exprs)) =
      macroNameFromDefinition macroDefinition == symbol ||
      any (isDependentOn macroDefinition) exprs
    isDependentOn macroDefinition (Parse.SExpression exprs) =
      any (isDependentOn macroDefinition) exprs
    isDependentOn _ _ = False
    isDependentOnAny macroDefinitions expr =
      any (`isDependentOn` expr) macroDefinitions

expansionPass ::
     (MonadBaseControl IO m, MonadError Error m, MonadIO m)
  => Parse.Expression
  -> m Parse.Expression
expansionPass programExpr = do
  let independentStatements =
        extractIndependentStatements $ programToStatements programExpr
  normalizedStatements <- traverse normalizeStatement independentStatements
  let nonconflictingStatements = filter canInclude normalizedStatements
  let (macroDefinitions, auxiliaryEnvironment) =
        foldl
          (\acc x ->
             case x of
               SMacroDefinition macroDefinition ->
                 acc & _1 %~ (macroDefinition :)
               _ -> acc & _2 %~ (<> [x]))
          ([], [])
          nonconflictingStatements
  expandMacros macroDefinitions auxiliaryEnvironment programExpr
  where
    canInclude :: Statement -> Bool
    canInclude =
      \case
        SDataDeclaration _ -> True
        SFunctionDefinition _ -> True
        SLanguagePragma _ -> True
        SMacroDefinition _ -> True
        SModuleDeclaration _ -> False
        SQualifiedImport _ -> True
        SRestrictedImport _ -> True
        STopLevel _ -> False
        STypeclassInstance _ -> True
        STypeSynonym _ -> True
        SUnrestrictedImport _ -> True
    programToStatements :: Parse.Expression -> [Parse.Expression]
    programToStatements (Parse.SExpression (Parse.Symbol "begin":stmts)) = stmts
    programToStatements _ =
      error "programToStatements must be passed a top-level program!"

exhaustivelyExpandMacros ::
     (MonadBaseControl IO m, MonadError Error m, MonadIO m)
  => Parse.Expression
  -> m Parse.Expression
exhaustivelyExpandMacros = exhaustM expansionPass

-- TODO This needs heavy optimization.
expandMacros ::
     (MonadBaseControl IO m, MonadError Error m, MonadIO m)
  => [MacroDefinition]
  -> [Statement]
  -> Parse.Expression
  -> m Parse.Expression
expandMacros macroDefinitions auxiliaryEnvironment =
  bottomUpTraverse $ \expression ->
    case expression of
      Parse.LiteralChar _ -> pure expression
      Parse.LiteralInt _ -> pure expression
      Parse.LiteralString _ -> pure expression
      Parse.SExpression xs ->
        Parse.SExpression <$>
        foldM
          (\acc x ->
             case x of
               Parse.LiteralChar _ -> pure $ acc ++ [x]
               Parse.LiteralInt _ -> pure $ acc ++ [x]
               Parse.LiteralString _ -> pure $ acc ++ [x]
               Parse.SExpression [] -> pure $ acc ++ [x]
               Parse.SExpression (function:args) ->
                 lookupMacroDefinition macroDefinitions function >>= \case
                   Just macroDefinition ->
                     (acc ++) <$>
                     expandMacroApplication
                       macroDefinition
                       auxiliaryEnvironment
                       args
                   Nothing -> pure $ acc ++ [x]
               Parse.Symbol _ -> pure $ acc ++ [x])
          []
          xs
      Parse.Symbol _ -> pure expression

expandMacroApplication ::
     (MonadBaseControl IO m, MonadError Error m, MonadIO m)
  => MacroDefinition
  -> [Statement]
  -> [Parse.Expression]
  -> m [Parse.Expression]
expandMacroApplication macroDef rawAuxEnv args = do
  auxEnv <- exhaustM pruneEnv rawAuxEnv
  result <- runMacro auxEnv
  case result of
    Right x -> Parse.parseMultiple x
    Left _ -> fatal "expandMacroApplication" "0001"
  where
    pruneEnv auxEnv = do
      result <- runMacro auxEnv
      pure $
        case result of
          Right _ -> auxEnv
          Left invalidDefs -> removeDefinitionsByName invalidDefs auxEnv
    runMacro auxEnv = do
      macroProgram <- generateMacroProgram macroDef auxEnv args
      uncurry3 evalMacro macroProgram

lookupMacroDefinition ::
     (MonadError Error m)
  => [MacroDefinition]
  -> Parse.Expression
  -> m (Maybe MacroDefinition)
lookupMacroDefinition macroDefinitions identifierExpression =
  case identifierExpression of
    Parse.LiteralChar _ -> pure Nothing
    Parse.LiteralInt _ -> pure Nothing
    Parse.LiteralString _ -> pure Nothing
    Parse.SExpression _ -> pure Nothing
    Parse.Symbol identifier ->
      case filter
             (\macroDefinition -> macroDefinition ^. name == identifier)
             macroDefinitions of
        [] -> pure Nothing
        [macroDefinition] -> pure $ Just macroDefinition
        _ -> throwError (MacroError "0012")

-- TODO This probably needs heavy optimization. If so, I will need to decrease the running time.
extractMacroDefinitions :: Statement -> [MacroDefinition]
extractMacroDefinitions (STopLevel topLevel) =
  foldl'
    (\env statement ->
       case statement of
         SMacroDefinition macroDefinition ->
           let newEnv = macroDefinition : env
               isDependentOnNewEnv x =
                 any (`isDefinitionDependentOnMacro` x) newEnv
           in filter (not . isDependentOnNewEnv) newEnv
         _ -> env)
    []
    (topLevel ^. statements)
extractMacroDefinitions _ = []

isDefinitionDependentOnMacro :: MacroDefinition -> MacroDefinition -> Bool
isDefinitionDependentOnMacro needle haystack =
  let definitionBodies = map snd (haystack ^. definitions)
  in any
       (isExpressionDependentOnMacro needle)
       (map denormalizeExpression definitionBodies)

isExpressionDependentOnMacro :: MacroDefinition -> Parse.Expression -> Bool
isExpressionDependentOnMacro _ (Parse.LiteralChar _) = False
isExpressionDependentOnMacro _ (Parse.LiteralInt _) = False
isExpressionDependentOnMacro _ (Parse.LiteralString _) = False
isExpressionDependentOnMacro needle (Parse.SExpression xs) =
  any (isExpressionDependentOnMacro needle) xs
isExpressionDependentOnMacro needle (Parse.Symbol x) = x == needle ^. name

stripMacroDefinitions :: Statement -> Statement
stripMacroDefinitions x =
  case x of
    STopLevel topLevel ->
      STopLevel $ (statements %~ filter (not . isMacroDefinition)) topLevel
    _ -> x
  where
    isMacroDefinition (SMacroDefinition _) = True
    isMacroDefinition _ = False

replaceName ::
     (MonadError Error m)
  => Identifier
  -> Identifier
  -> Statement
  -> m Statement
replaceName oldName newName =
  normalize . bottomUpFmap replaceSymbol . denormalizeStatement
  where
    normalize expr =
      normalizeStatement expr `catchError` \_ ->
        throwError (MacroError $ "Invalid macro name: `" <> oldName <> "`!")
    replaceSymbol expr =
      case expr of
        Parse.Symbol identifier ->
          Parse.Symbol $
          if identifier == oldName
            then newName
            else identifier
        _ -> expr
