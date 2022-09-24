{-# OPTIONS_GHC -fno-warn-orphans #-}

-- | This module implement the type Capability.DumpFetcher for App
module AppCapability.DumpFetchor
  ( fetchDump,
  )
where

import AppM
import As
import Capability.DumpFetchor
import Core.JavaAnalyzerRunner
import Core.MyError
import Core.Types
import Error
import Has
import Path
import Path.IO
import System.Process.Typed
import qualified Text.URI as URI
import Utils

instance DumpFetchorM AppM' where
  fetchDump file dirSuffix (Local' path) = do
    outDumpHome <- grab @OutputPath' >>= \p -> someDirToAbs $ appendDirToSomeDir (outputFetchedDumpHome' p) dirSuffix
    ensureDir outDumpHome
    someFileToAbs path >>= \from -> copyFile from $ outDumpHome </> file
    pure $ outDumpHome </> file
  fetchDump file dirSuffix (HttpUrl' url) = do
    outDumpHome <- grab @OutputPath' >>= \p -> someDirToAbs $ appendDirToSomeDir (outputFetchedDumpHome' p) dirSuffix
    ensureDir outDumpHome
    cmdPaths <- grab @CommandPath'
    curlOpts' <- grab @CurlCmdLineOptions'
    runProcess_ $
      proc
        (fromSomeFile $ cmdWgetPath' cmdPaths)
        [ "--quiet",
          "--no-proxy",
          "--continue",
          "--output-document=" <> toFilePath (outDumpHome </> file),
          URI.renderStr $ fromMaybe url $ URI.relativeTo url $ curlCmdLineDownloadBaseUrl' curlOpts'
        ]
    pure $ outDumpHome </> file
  fetchDump _ _ (S3Path' _) = throwError $ as $ NotImplementedYet "Should not get to here."
