module Explorer.Api.Socket where

import Prelude
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Exception (Error)
import Control.SocketIO.Client (Event, Host)
import Data.Argonaut.Core (Json)
import Data.Array (foldl, last)
import Data.Either (Either)
import Data.Foreign (Foreign)
import Data.Generic (class Generic, gShow)
import Data.Maybe (fromMaybe)
import Data.String (Pattern(..), Replacement(..), replaceAll, split, trim)
import Debug.Trace (traceAnyM)
import Explorer.Api.Helper (decodeResult')
import Explorer.Types.Actions (Action(..), ActionChannel)
import Explorer.Util.Config (Protocol(..))
import Pos.Explorer.Socket.Methods (ClientEvent, ServerEvent)
import Pos.Explorer.Web.ClientTypes (CTxId)
import Signal.Channel (CHANNEL, send)


-- | We need to have socket.io on port 8110 when testing (without `https`).
-- When we deploy on production we use nginx forwarding, so we send it to the
-- default port (443) and nginx forwards it to 8110 on the server.
mkSocketHost :: Protocol -> String -> Host
mkSocketHost Http  hostname = "http://"  <> hostname <> ":8110"
mkSocketHost Https hostname = "https://" <> hostname

-- events

class SocketEvent a where
    toEvent :: a -> String

instance socketEventServerEvent :: SocketEvent ClientEvent where
    toEvent = showEvent

instance socketEventClientEvent :: SocketEvent ServerEvent where
    toEvent = showEvent

-- | Helper to grab event names from ClientEvent | ServerEvent
-- | _Note_: We can't create a generic show instances from these types,
-- | because they are generated by purescript-bridge
showEvent :: forall b. (Generic b) => b -> String
showEvent t =
    trim <<< getModuleNames <<< split (Pattern " ") $ gShow t
    where
        getModuleNames m = foldl (\acc mn -> acc <> " " <> getModuleName mn) "" m
        getModuleName n = fromMaybe "" <<< last $ split (Pattern ".") n


-- | Helper function to remove """ from event names
cleanEventName :: Event -> Event
cleanEventName = replaceAll (Pattern "\"") (Replacement "")

connectEvent :: Event
connectEvent = "connect"

closeEvent :: Event
closeEvent = "close"

-- event handler

connectHandler :: forall eff. ActionChannel -> Foreign
    -> Eff (channel :: CHANNEL | eff) Unit
connectHandler channel _ =
    send channel $ SocketConnected true

closeHandler :: forall eff. ActionChannel -> Foreign
    -> Eff (channel :: CHANNEL | eff) Unit
closeHandler channel _ =
    send channel $ SocketConnected false

addressTxsUpdatedEventHandler :: forall eff. ActionChannel -> Json
    -> Eff (channel :: CHANNEL | eff) Unit
addressTxsUpdatedEventHandler channel json =
    let result = decodeResult' json in
    send channel $ SocketAddressTxsUpdated result

blocksPageUpdatedEventHandler :: forall eff. ActionChannel -> Json
    -> Eff (channel :: CHANNEL | eff) Unit
blocksPageUpdatedEventHandler channel json =
    let result = decodeResult' json in
    send channel $ SocketBlocksPageUpdated result

txsUpdatedHandler :: forall eff. ActionChannel -> Json
    -> Eff (channel :: CHANNEL | eff) Unit
txsUpdatedHandler channel json =
    let result = decodeResult' json in
    send channel $ SocketTxsUpdated result


callYouEventHandler :: forall eff. ActionChannel -> Foreign -> Eff eff Unit
callYouEventHandler channel _ =
    -- just an empty callback to be connected with socket.io
    pure unit

-- all following event handler are for debugging only

callYouStringEventHandler :: forall eff. ActionChannel -> String
    -> Eff (channel :: CHANNEL | eff) Unit
callYouStringEventHandler channel str = do
    traceAnyM "callYouStringEventHandler"
    traceAnyM str
    send channel NoOp

callYouCTxIdEventHandler :: forall eff. ActionChannel -> Json
    -> Eff (channel :: CHANNEL | eff) Unit
callYouCTxIdEventHandler channel json = do
    traceAnyM "callYouCTxIdEventHandler"
    traceAnyM json
    let result = decodeResult' json
    traceAnyM (result :: Either Error CTxId)
    send channel NoOp
