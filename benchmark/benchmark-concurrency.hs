import Criterion.Main
import Data.List (isPrefixOf, partition)
import Data.Time (getCurrentTime)
import System.Environment (getArgs, withArgs)

import Clash.Driver
import Clash.GHC.PartialEval
import Clash.GHC.Evaluator

import BenchmarkCommon

main :: IO ()
main = do
  args <- getArgs
  let (idirs0,rest)         = partition ((== "-i") . take 2) args
      idirs1                = ".":map (drop 2) idirs0
      (fileArgs,optionArgs) = break (isPrefixOf "-") rest
      tests | null fileArgs = concurrencyTests
            | otherwise     = fileArgs

  withArgs optionArgs (defaultMain $ fmap (benchFile idirs1) tests)
 where
  concurrencyTests =
    [ "benchmark/tests/ManyEntitiesEqual.hs"
    , "benchmark/tests/ManyEntitiesVaried.hs"
    ]

benchFile :: [FilePath] -> FilePath -> Benchmark
benchFile idirs src =
  env ((,) <$> runInputStage idirs src <*> getCurrentTime) $
    \ ~((clashEnv, clashDesign),startTime) -> do
      bench ("Generating HDL: " ++ src)
            (nfIO (generateHDL clashEnv clashDesign (Just backend)
                               typeTrans ghcEvaluator
                               evaluator Nothing startTime))
