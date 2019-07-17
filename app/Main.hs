{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}
module Main where
import Axel(applyInfix_AXEL_AUTOGENERATED_MACRO_DEFINITION,def_AXEL_AUTOGENERATED_MACRO_DEFINITION,defmacro_AXEL_AUTOGENERATED_MACRO_DEFINITION,fnCase_AXEL_AUTOGENERATED_MACRO_DEFINITION,do'_AXEL_AUTOGENERATED_MACRO_DEFINITION,quasiquote_AXEL_AUTOGENERATED_MACRO_DEFINITION)
import Prelude hiding (putStrLn)
import Axel.Eff.Console(putStrLn)
import qualified Axel.Eff.Console as Effs(Console)
import qualified Axel.Eff.Console as Console(runEff)
import qualified Axel.Eff.FileSystem as FS(runEff)
import qualified Axel.Eff.FileSystem as Effs(FileSystem)
import qualified Axel.Eff.Ghci as Ghci(runEff)
import qualified Axel.Eff.Ghci as Effs(Ghci)
import qualified Axel.Eff.Process as Proc(runEff)
import qualified Axel.Eff.Process as Effs(Process)
import qualified Axel.Eff.Resource as Res(runEff)
import qualified Axel.Eff.Resource as Effs(Resource)
import qualified Axel.Error as Error(unsafeRunEff)
import Axel.Haskell.File(convertFile',transpileFile')
import Axel.Haskell.Project(buildProject,runProject)
import Axel.Haskell.Stack(axelStackageVersion)
import Axel.Macros(ModuleInfo)
import Axel.Parse.Args(Command(Convert,File,Project,Version),commandParser)
import qualified Axel.Sourcemap as SM(Error)
import Control.Monad(void)
import Control.Monad.Freer(Eff)
import qualified Control.Monad.Freer as Effs(runM)
import qualified Control.Monad.Freer.Error as Effs(Error)
import Control.Monad.Freer.State(evalState)
import qualified Data.Map as Map(empty)
import Options.Applicative((<**>),execParser,helper,info,progDesc)
type AppEffs = (Eff '[Effs.Console, Effs.Error SM.Error, Effs.FileSystem, Effs.Ghci, Effs.Process, Effs.Resource, IO])
runApp  = ((.) Effs.runM ((.) Res.runEff ((.) Proc.runEff ((.) Ghci.runEff ((.) FS.runEff ((.) Error.unsafeRunEff Console.runEff))))))
runApp :: (((->) (AppEffs a)) (IO a))
app (Convert filePath) = (void (convertFile' filePath))
app (File filePath) = (void ((evalState @ModuleInfo Map.empty) (transpileFile' filePath)))
app (Project ) = ((>>) buildProject runProject)
app (Version ) = (putStrLn ((<>) "Axel version " axelStackageVersion))
app :: (((->) Command) (AppEffs ()))
main  = do { modeCommand <- execParser $ info (commandParser <**> helper) (progDesc "The command to run."); runApp $ app modeCommand}
main :: (IO ())