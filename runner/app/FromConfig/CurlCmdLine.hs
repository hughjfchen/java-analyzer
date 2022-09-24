{-# LANGUAGE RecordWildCards #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- |
-- Copyright: (c) 2021 Hugh JF Chen
-- License: MIT
-- Maintainer: Hugh JF Chen <hugh.jf.chen@gmail.com>
-- Stability: stable
-- Portability: portable
--
-- FromConfig instance for CurlCmdLineOptions
module FromConfig.CurlCmdLine () where

import Conferer.FromConfig
import Core.Types (CurlCmdLineOptions (..))
import Data.Dynamic

-- | Deconstruct a 'Core.Types.MATCmdLineOptions' into a many key/dynamic pairs to
-- provide valid defaults for downstream 'fetchFromConfig'
deconstructCurlCmdLineOptionsToDefaults :: CurlCmdLineOptions -> [(Key, Dynamic)]
deconstructCurlCmdLineOptionsToDefaults CurlCmdLineOptions {..} =
  [ ("loginUser", toDyn curlCmdLineLoginUser),
    ("loginPIN", toDyn curlCmdLineLoginPIN),
    ("loginUrl", toDyn curlCmdLineLoginUrl),
    ("uploadUrl", toDyn curlCmdLineUploadUrl),
    ("downloadBaseUrl", toDyn curlCmdLineDownloadBaseUrl)
  ]

instance DefaultConfig CurlCmdLineOptions where
  configDef =
    CurlCmdLineOptions
      { curlCmdLineLoginUser = "",
        curlCmdLineLoginPIN = "",
        curlCmdLineLoginUrl = "",
        curlCmdLineUploadUrl = "",
        curlCmdLineDownloadBaseUrl = ""
      }

instance FromConfig CurlCmdLineOptions where
  fromConfig key originalConfig = do
    config <- addDefaultsAfterDeconstructingToDefaults deconstructCurlCmdLineOptionsToDefaults key originalConfig

    curlCmdLineLoginUser <- fetchFromConfig (key /. "loginUser") config
    curlCmdLineLoginPIN <- fetchFromConfig (key /. "loginPIN") config
    curlCmdLineLoginUrl <- fetchFromConfig (key /. "loginUrl") config
    curlCmdLineUploadUrl <- fetchFromConfig (key /. "uploadUrl") config
    curlCmdLineDownloadBaseUrl <- fetchFromConfig (key /. "downloadBaseUrl") config

    pure CurlCmdLineOptions {..}
