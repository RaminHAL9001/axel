{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell #-}

module Lihsp.AST where

import Control.Lens.Operators ((^.))
import Control.Lens.TH (makeFieldsNoPrefix)

import Data.Semigroup ((<>))

import Lihsp.Utils.Display
  ( Bracket(Parentheses, SingleQuotes, SquareBrackets)
  , Delimiter(Commas, Newlines, Pipes, Spaces)
  , delimit
  , isOperator
  , renderBlock
  , renderPragma
  , surround
  )

type Identifier = String

data FunctionApplication = FunctionApplication
  { _function :: Expression
  , _arguments :: [Expression]
  } deriving (Eq)

data TypeDefinition
  = ProperType Identifier
  | TypeConstructor FunctionApplication
  deriving (Eq)

instance Show TypeDefinition where
  show :: TypeDefinition -> String
  show (ProperType x) = x
  show (TypeConstructor x) = show x

data DataDeclaration = DataDeclaration
  { _typeDefinition :: TypeDefinition
  , _constructors :: [FunctionApplication]
  } deriving (Eq)

newtype ArgumentList =
  ArgumentList [Expression]
  deriving (Eq)

instance Show ArgumentList where
  show :: ArgumentList -> String
  show (ArgumentList arguments) = concatMap show arguments

data FunctionDefinition = FunctionDefinition
  { _name :: Identifier
  , _typeSignature :: FunctionApplication
  , _definitions :: [(ArgumentList, Expression)]
  } deriving (Eq)

data Import
  = ImportItem Identifier
  | ImportType Identifier
               [Identifier]
  deriving (Eq)

instance Show Import where
  show :: Import -> String
  show (ImportItem x) =
    if isOperator x
      then surround Parentheses x
      else x
  show (ImportType typeName imports) =
    typeName <> surround Parentheses (delimit Commas imports)

newtype ImportList =
  ImportList [Import]
  deriving (Eq)

instance Show ImportList where
  show :: ImportList -> String
  show (ImportList importList) =
    surround Parentheses $ delimit Commas $ map show importList

newtype LanguagePragma = LanguagePragma
  { _language :: Identifier
  } deriving (Eq)

data LetBlock = LetBlock
  { _bindings :: [(Identifier, Expression)]
  , _body :: Expression
  } deriving (Eq)

data MacroDefinition = MacroDefinition
  { _name :: Identifier
  , _definitions :: [(ArgumentList, Expression)]
  } deriving (Eq)

data QualifiedImport = QualifiedImport
  { _moduleName :: Identifier
  , _alias :: Identifier
  , _imports :: ImportList
  } deriving (Eq)

data RestrictedImport = RestrictedImport
  { _moduleName :: Identifier
  , _imports :: ImportList
  } deriving (Eq)

data TypeclassInstance = TypeclassInstance
  { _instanceName :: Expression
  , _definitions :: [FunctionDefinition]
  } deriving (Eq)

data TypeSynonym = TypeSynonym
  { _alias :: Expression
  , _definition :: Expression
  } deriving (Eq)

data Expression
  = EFunctionApplication FunctionApplication
  | EIdentifier Identifier
  | ELetBlock LetBlock
  | ELiteral Literal
  deriving (Eq)

instance Show Expression where
  show :: Expression -> String
  show (EFunctionApplication x) = show x
  show (EIdentifier x) =
    if isOperator x
      then surround Parentheses x
      else x
  show (ELetBlock x) = show x
  show (ELiteral x) = show x

data Literal
  = LChar Char
  | LInt Int
  | LList [Expression]
  deriving (Eq)

instance Show Literal where
  show :: Literal -> String
  show (LInt int) = show int
  show (LChar char) = surround SingleQuotes [char]
  show (LList list) = surround SquareBrackets $ delimit Commas (map show list)

data Statement
  = SDataDeclaration DataDeclaration
  | SFunctionDefinition FunctionDefinition
  | SLanguagePragma LanguagePragma
  | SMacroDefinition MacroDefinition
  | SModuleDeclaration Identifier
  | SQualifiedImport QualifiedImport
  | SRestrictedImport RestrictedImport
  | STypeclassInstance TypeclassInstance
  | STypeSynonym TypeSynonym
  | SUnrestrictedImport Identifier
  deriving (Eq)

instance Show Statement where
  show :: Statement -> String
  show (SDataDeclaration x) = show x
  show (SFunctionDefinition x) = show x
  show (SLanguagePragma x) = show x
  show (SMacroDefinition x) = show x
  show (SModuleDeclaration x) = "module " <> x <> " where"
  show (SQualifiedImport x) = show x
  show (SRestrictedImport x) = show x
  show (STypeclassInstance x) = show x
  show (STypeSynonym x) = show x
  show (SUnrestrictedImport x) = show x

type Program = [Statement]

makeFieldsNoPrefix ''DataDeclaration

makeFieldsNoPrefix ''FunctionApplication

makeFieldsNoPrefix ''FunctionDefinition

makeFieldsNoPrefix ''LanguagePragma

makeFieldsNoPrefix ''LetBlock

makeFieldsNoPrefix ''MacroDefinition

makeFieldsNoPrefix ''QualifiedImport

makeFieldsNoPrefix ''RestrictedImport

makeFieldsNoPrefix ''TypeclassInstance

makeFieldsNoPrefix ''TypeSynonym

instance Show FunctionApplication where
  show :: FunctionApplication -> String
  show functionApplication =
    surround Parentheses $
    show (functionApplication ^. function) <> " " <>
    delimit Spaces (map show $ functionApplication ^. arguments)

showFunctionDefinition :: Identifier -> (ArgumentList, Expression) -> String
showFunctionDefinition functionName (pattern', definitionBody) =
  functionName <> " " <> show pattern' <> " = " <> show definitionBody

instance Show FunctionDefinition where
  show :: FunctionDefinition -> String
  show functionDefinition =
    delimit Newlines $
    (functionDefinition ^. name <> " :: " <>
     show (functionDefinition ^. typeSignature)) :
    map
      (showFunctionDefinition $ functionDefinition ^. name)
      (functionDefinition ^. definitions)

instance Show DataDeclaration where
  show :: DataDeclaration -> String
  show dataDeclaration =
    "data " <> show (dataDeclaration ^. typeDefinition) <> " = " <>
    delimit Pipes (map show $ dataDeclaration ^. constructors)

instance Show LanguagePragma where
  show :: LanguagePragma -> String
  show languagePragma = renderPragma $ "LANGUAGE " <> languagePragma ^. language

instance Show LetBlock where
  show :: LetBlock -> String
  show letBlock =
    "let " <> renderBlock (map showBinding (letBlock ^. bindings)) <> " in " <>
    show (letBlock ^. body)
    where
      showBinding (identifier, value) = identifier <> " = " <> show value

instance Show MacroDefinition where
  show :: MacroDefinition -> String
  show macroDefinition =
    delimit Newlines $
    macroDefinition ^. name :
    map
      (showFunctionDefinition $ macroDefinition ^. name)
      (macroDefinition ^. definitions)

instance Show QualifiedImport where
  show :: QualifiedImport -> String
  show qualifiedImport =
    "import " <> qualifiedImport ^. moduleName <> " as " <> qualifiedImport ^.
    alias <>
    show (qualifiedImport ^. imports)

instance Show RestrictedImport where
  show :: RestrictedImport -> String
  show restrictedImport =
    "import " <> restrictedImport ^. moduleName <>
    show (restrictedImport ^. imports)

instance Show TypeclassInstance where
  show :: TypeclassInstance -> String
  show typeclassInstance =
    "instance " <> show (typeclassInstance ^. instanceName) <> " where " <>
    renderBlock (map show $ typeclassInstance ^. definitions)

instance Show TypeSynonym where
  show :: TypeSynonym -> String
  show typeSynonym =
    "type " <> show (typeSynonym ^. alias) <> " = " <>
    show (typeSynonym ^. definition)

-- TODO Either replace with `MonoTraversable` or make `Expression` polymorphic
--      (in which case, use `Traversable`, recursion schemes, etc.). The latter
--      would be preferable.
-- TODO Remove the dependency on `Monad` (since the standard `traverse` only
--      requires an `Applicative` instance).
traverseExpression ::
     (Monad m) => (Expression -> m Expression) -> Expression -> m Expression
traverseExpression f x =
  case x of
    EFunctionApplication functionApplication ->
      let newArguments =
            traverse (traverseExpression f) (functionApplication ^. arguments)
          newFunction = traverseExpression f (functionApplication ^. function)
      in f =<<
         (EFunctionApplication <$>
          (FunctionApplication <$> newFunction <*> newArguments))
    EIdentifier _ -> f x
    ELetBlock _ -> f x
    ELiteral _ -> f x
