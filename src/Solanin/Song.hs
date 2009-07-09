module Solanin.Song (Song(..),

                     open,
                     songExts) where

import qualified Codec.Binary.UTF8.String as U
import Data.Maybe
import Data.Binary
import qualified Sound.TagLib as TagLib
import System.Directory
import System.FilePath

data Song = Song
  { songPath     :: FilePath
  , songTrack    :: Integer
  , songTitle    :: String
  , songArtist   :: String
  , songAlbum    :: String
  , songDuration :: Integer
  } deriving (Show, Eq)

instance Ord Song where
  compare x y | a x == a y && t x /= t y = t x `compare` t y
              | a x == a y && t x == t y = p x `compare` p y
              | otherwise  = a x `compare` a y
    where
      p = songPath
      a = songAlbum
      t = songTrack

instance Binary Song where
  put (Song path track title artist album duration) = do
    put path
    put track
    put title
    put artist
    put album
    put duration
  get = do
    path     <- get
    track    <- get
    title    <- get
    artist   <- get
    album    <- get
    duration <- get
    return $ Song path track title artist album duration

songExts :: [String]
songExts = [".mp3", ".flac", ".ape", ".tta", ".wav"]

open :: [String] -> FilePath -> IO (Maybe Song)
open exts f = catch p (const (return Nothing))
  where
    p = do
      -- TagLib.open doesn't throw exceptions, so we have to check
      -- ourselves if we can read the file.
      perms <- getPermissions f
      if readable perms && takeExtension f `elem` exts then do
        tf    <- TagLib.open (U.decodeString f)
        dura  <- tagDuration tf
        let r = return . Just $ Song
                  { songPath     = f
                  , songTrack    = 0
                  , songTitle    = takeBaseName f
                  , songArtist   = ""
                  , songAlbum    = ""
                  , songDuration = dura
                  }
        maybe r (g r dura) tf
        else return Nothing

    tagDuration (Just tf) = do
      ap <- TagLib.audioProperties tf
      case ap of
        Just ap' -> TagLib.duration ap'
        Nothing  -> return 0
    tagDuration Nothing = return 0

    g r duration tf = do
      t <- TagLib.tag tf
      maybe r (g' duration) t
    g' duration t = do
      track  <- TagLib.track t
      title  <- TagLib.title t
      artist <- TagLib.artist t
      album  <- TagLib.album t

      return . Just $ Song
        { songPath     = f
        , songTrack    = track
        , songTitle    = U.encodeString title
        , songArtist   = U.encodeString artist
        , songAlbum    = U.encodeString album
        , songDuration = duration
        }