{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE TypeSynonymInstances #-}

-- |
-- Module:      Data.Text.I18n
-- Copyright:   (c) 2011-2016 Eugene Grigoriev
-- License:     BSD3
-- Maintainer:  Philip Cunningham <hello@filib.io>
-- Stability:   experimental
-- Portability: portable
--
-- Internationalisation support for Haskell.

module Data.Text.I18n (
    -- * Internationalisation Monad Functions
    gettext,
    localize,
    withContext,
    withLocale,
    -- * Re-exports
    module Data.Text.I18n.Types,
    ) where

import           Control.Monad.Identity
import           Control.Monad.Reader
import qualified Data.Map               as Map
import           Data.Maybe
import qualified Data.Text              as T
import           Data.Text.I18n.Types

-- $setup
-- >>> :set -XOverloadedStrings
-- >>> import qualified Data.Text.I18n    as I18n
-- >>> import qualified Data.Text.I18n.Po as I18n
-- >>> let example = I18n.gettext "Like tears in rain."
-- >>> (l10n, _) <- I18n.getL10n "./test/locale"
--
-- | The heart of I18n monad.
gettext :: T.Text -> I18n T.Text
gettext msgid = do
  (loc, l10n, ctxt) <- ask
  case localizeMsgid l10n loc ctxt (Msgid msgid) of
    Just msgstr -> return msgstr
    Nothing ->
      case ctxt of
        Just _  -> withContext Nothing (gettext msgid)
        Nothing -> return msgid

-- | Top level localization function.
--
-- Examples:
--
-- >>> I18n.localize l10n (I18n.Locale "cym") example
-- "Fel dagrau yn y glaw."
--
-- When the translation doesn't exist:
--
-- >>> I18n.localize l10n (I18n.Locale "ru") example
-- "Like tears in rain."
localize :: L10n    -- ^ Structure containing localization data
         -> Locale  -- ^ Locale to use
         -> I18n a  -- ^ Inernationalized expression
         -> a       -- ^ Localized expression
localize l10n loc expression = runIdentity $ runReaderT expression (loc, l10n, Nothing)

-- | Sets a local 'Context' for an internationalized expression. If there is no translation, then no
-- context version is tried.
--
-- Examples:
--
-- >>> let example2 = I18n.withContext (Just (Context "Attack ships on fire off the shoulder of Orion.")) example
-- >>> I18n.localize l10n (I18n.Locale "cym") example2
-- "Fel dagrau yn y glaw."
withContext :: Maybe Context -- ^ Context to use
            -> I18n a        -- ^ Internationalized expression
            -> I18n a        -- ^ New internationalized expression
withContext ctxt expression = do
  (lang, l10n, _) <- ask
  local (const (lang, l10n, ctxt)) expression

-- | Sets a local 'Locale' for an internationalized expression.
--
-- Examples:
--
-- >>> let example3 = I18n.withLocale (I18n.Locale "en") example
-- >>> I18n.localize l10n (I18n.Locale "cym") example3
-- "Like tears in rain."
withLocale :: Locale    -- ^ Locale to use
           -> I18n a    -- ^ Internationalized expression
           -> I18n a    -- ^ New internationalized expression.
withLocale loc expression = do
  (_, l10n, ctxt) <- ask
  local (const (loc, l10n, ctxt)) expression

-- | Internal lookup function.
localizeMsgid :: L10n -> Locale -> Maybe Context -> Msgid -> Maybe T.Text
localizeMsgid l10n loc ctxt msgid = do
  local' <- Map.lookup loc l10n
  contextual <- Map.lookup ctxt local'
  msgstrs <- Map.lookup msgid contextual
  case listToMaybe msgstrs of
    Nothing              -> Nothing
    Just (Msgstr "")     -> Nothing
    Just (Msgstr msgstr) -> Just msgstr
