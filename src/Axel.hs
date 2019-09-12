{-# OPTIONS_GHC -Wno-incomplete-patterns #-}
module Axel where
import qualified Axel.Parse.AST as AST
import qualified Axel.Parse.AST as AST
import qualified Axel.Sourcemap as SM
import Axel.Utils.Recursion(bottomUpFmap)
import Data.IORef(IORef,modifyIORef,newIORef,readIORef)
import System.FilePath(takeFileName)
import System.IO.Unsafe(unsafePerformIO)
import Control.Lens.Cons(snoc)
expandDo' ((:) (AST.SExpression _ [(AST.Symbol _ "<-"),var,val]) rest) = (AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 43 8))) (concat [[(AST.Symbol (Just ((,) "axelTemp/4851124621589702297/result.axel" (SM.Position 1 146))) ">>=")],[val],[(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 43 18))) (concat [[(AST.Symbol (Just ((,) "axelTemp/4851124621589702297/result.axel" (SM.Position 1 233))) "\\")],[(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 43 21))) (concat [[var]]))],[(expandDo' rest)]]))]]))
expandDo' ((:) (AST.SExpression _ ((:) (AST.Symbol _ "let") bindings)) rest) = (AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 45 8))) (concat [[(AST.Symbol (Just ((,) "axelTemp/4851124621589702297/result.axel" (SM.Position 2 150))) "let")],[(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 45 13))) (concat [(AST.toExpressionList bindings)]))],[(expandDo' rest)]]))
expandDo' ((:) val rest) = (case rest of {[] -> val;_ -> (AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 49 13))) (concat [[(AST.Symbol (Just ((,) "axelTemp/4851124621589702297/result.axel" (SM.Position 3 127))) ">>")],[val],[(expandDo' rest)]]))})
expandDo' :: ((->) ([] SM.Expression) SM.Expression)
gensymCounter  = (unsafePerformIO (newIORef 0))
gensymCounter :: (IORef Int)
{-# NOINLINE gensymCounter #-}
gensym  = ((>>=) (readIORef gensymCounter) (\suffix -> (let {identifier = ((<>) "aXEL_AUTOGENERATED_IDENTIFIER_" (show suffix))} in ((>>) (modifyIORef gensymCounter succ) (pure (AST.Symbol Nothing identifier))))))
gensym :: (IO SM.Expression)
isPrelude  = ((.) ((==) "Axel.axel") takeFileName)
isPrelude :: ((->) FilePath Bool)
preludeMacros  = ["applyInfix","defmacro","def","do'","\\case","syntaxQuote"]
preludeMacros :: ([] String)
applyInfix_AXEL_AUTOGENERATED_MACRO_DEFINITION [x,op,y] = (pure [(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 17 17))) (concat [[op],[x],[y]]))])
defmacro_AXEL_AUTOGENERATED_MACRO_DEFINITION ((:) name cases) = (pure (map (\(AST.SExpression _ ((:) args body)) -> (AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 22 55))) (concat [[(AST.Symbol (Just ((,) "src/Axel.axel" (SM.Position 22 56))) "=macro")],[name],[(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 22 69))) (concat [[args]]))],(AST.toExpressionList body)]))) cases))
def_AXEL_AUTOGENERATED_MACRO_DEFINITION ((:) name ((:) typeSig cases)) = (pure (snoc (map (\x -> (AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 30 32))) (concat [[(AST.Symbol (Just ((,) "axelTemp/8148319292167479833/result.axel" (SM.Position 1 141))) "=")],[name],(AST.toExpressionList x)]))) cases) (AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 32 20))) (concat [[(AST.Symbol (Just ((,) "axelTemp/8148319292167479833/result.axel" (SM.Position 1 262))) "::")],[name],[typeSig]]))))
syntaxQuote_AXEL_AUTOGENERATED_MACRO_DEFINITION [x] = (pure [(AST.quoteExpression (const (AST.Symbol Nothing "_")) x)])
do'_AXEL_AUTOGENERATED_MACRO_DEFINITION input = (pure [(expandDo' input)])
aXEL_SYMBOL_BACKSLASH_case_AXEL_AUTOGENERATED_MACRO_DEFINITION cases = (fmap (\varId -> [(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 68 15))) (concat [[(AST.Symbol (Just ((,) "axelTemp/2250396804993982805/result.axel" (SM.Position 1 116))) "\\")],[(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 68 18))) (concat [[varId]]))],[(AST.SExpression (Just ((,) "src/Axel.axel" (SM.Position 68 27))) (concat [[(AST.Symbol (Just ((,) "axelTemp/2250396804993982805/result.axel" (SM.Position 1 281))) "case")],[varId],(AST.toExpressionList cases)]))]]))]) gensym)
applyInfix_AXEL_AUTOGENERATED_MACRO_DEFINITION :: [AST.Expression SM.SourceMetadata] -> IO [AST.Expression SM.SourceMetadata]
defmacro_AXEL_AUTOGENERATED_MACRO_DEFINITION :: [AST.Expression SM.SourceMetadata] -> IO [AST.Expression SM.SourceMetadata]
def_AXEL_AUTOGENERATED_MACRO_DEFINITION :: [AST.Expression SM.SourceMetadata] -> IO [AST.Expression SM.SourceMetadata]
syntaxQuote_AXEL_AUTOGENERATED_MACRO_DEFINITION :: [AST.Expression SM.SourceMetadata] -> IO [AST.Expression SM.SourceMetadata]
do'_AXEL_AUTOGENERATED_MACRO_DEFINITION :: [AST.Expression SM.SourceMetadata] -> IO [AST.Expression SM.SourceMetadata]
aXEL_SYMBOL_BACKSLASH_case_AXEL_AUTOGENERATED_MACRO_DEFINITION :: [AST.Expression SM.SourceMetadata] -> IO [AST.Expression SM.SourceMetadata]