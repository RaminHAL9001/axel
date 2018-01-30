-- NOTE Because this file will be used as the header of auto-generated macro programs,
--      it can't have any project-specific dependencies (such as `Fix`).
module Axel.Parse.AST where

import Data.IORef (IORef, modifyIORef, newIORef, readIORef)
import System.IO.Unsafe (unsafePerformIO)

-- TODO `Expression` should probably be `Traversable`, use recursion schemes, etc.
--      I should provide `toFix` and `fromFix` functions for macros to take advantage of.
--      (Maybe all macros have the argument automatically `fromFix`-ed to make consumption simpler?)
data Expression
  = LiteralChar Char
  | LiteralInt Int
  | LiteralString String
  | SExpression [Expression]
  | Symbol String
  deriving (Eq, Show)

-- ******************************
-- Internal utilities
-- ******************************
toAxel :: Expression -> String
toAxel (LiteralChar x) = ['\\', x]
toAxel (LiteralInt x) = show x
toAxel (LiteralString xs) = "\"" ++ xs ++ "\""
toAxel (SExpression xs) = "(" ++ unwords (map toAxel xs) ++ ")"
toAxel (Symbol x) = x

-- ******************************
-- Macro definition utilities
-- ******************************
{-# NOINLINE gensymCounter #-}
gensymCounter :: IORef Int
gensymCounter = unsafePerformIO $ newIORef 0

gensym :: IO Expression
gensym = do
  suffix <- readIORef gensymCounter
  let identifier = "aXEL_AUTOGENERATED_IDENTIFIER_" ++ show suffix
  modifyIORef gensymCounter succ
  return $ Symbol identifier
