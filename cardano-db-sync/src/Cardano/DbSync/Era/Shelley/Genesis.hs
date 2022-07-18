{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Cardano.DbSync.Era.Shelley.Genesis
  ( insertValidateGenesisDist
  ) where

import           Cardano.Prelude

import           Cardano.BM.Trace (Trace, logError, logInfo)

import           Control.Monad.Trans.Control (MonadBaseControl)
import           Control.Monad.Trans.Except.Extra (newExceptT)

import qualified Cardano.Db as DB

import           Cardano.DbSync.Cache
import qualified Cardano.DbSync.Era.Shelley.Generic.Util as Generic
import           Cardano.DbSync.Era.Shelley.Insert
import           Cardano.DbSync.Era.Util (liftLookupFail)
import           Cardano.DbSync.Error
import           Cardano.DbSync.Util

import qualified Cardano.Ledger.Address as Ledger
import qualified Cardano.Ledger.Coin as Ledger
import           Cardano.Ledger.Credential (Credential (KeyHashObj))
import           Cardano.Ledger.Era (Crypto)
import qualified Cardano.Ledger.Shelley.Genesis as Shelley
import           Cardano.Ledger.Shelley.Scripts ()
import qualified Cardano.Ledger.Shelley.Tx as ShelleyTx
import qualified Cardano.Ledger.Shelley.TxBody as Shelley
import qualified Cardano.Ledger.Shelley.UTxO as Shelley

import           Cardano.Slotting.Block (BlockNo (..))
import           Cardano.Slotting.Slot (EpochNo (..))

import qualified Data.ByteString.Char8 as BS
import qualified Data.Map.Strict as Map
import           Data.Time.Clock (UTCTime (..))
import qualified Data.Time.Clock as Time

import           Database.Persist.Sql (SqlBackend)

import           Ouroboros.Consensus.Cardano.Block (StandardCrypto, StandardShelley)
import           Ouroboros.Consensus.Shelley.Node (ShelleyGenesis (..), ShelleyGenesisStaking (..),
                   emptyGenesisStaking)

import           Paths_cardano_db_sync (version)


-- | Idempotent insert the initial Genesis distribution transactions into the DB.
-- If these transactions are already in the DB, they are validated.
-- 'shelleyInitiation' is True for testnets that fork at 0 to Shelley.
insertValidateGenesisDist
    :: SqlBackend -> Trace IO Text -> Text -> ShelleyGenesis StandardShelley -> Bool
    -> ExceptT SyncNodeError IO ()
insertValidateGenesisDist backend tracer networkName cfg shelleyInitiation = do
    -- Setting this to True will log all 'Persistent' operations which is great
    -- for debugging, but otherwise *way* too chatty.
    when (not shelleyInitiation && (hasInitialFunds || hasStakes)) $ do
      liftIO $ logError tracer $ renderSyncNodeError NEIgnoreShelleyInitiation
      throwError NEIgnoreShelleyInitiation
    if False
      then newExceptT $ DB.runDbIohkLogging backend tracer insertAction
      else newExceptT $ DB.runDbIohkNoLogging backend insertAction
  where
    hasInitialFunds :: Bool
    hasInitialFunds = not $ Map.null $ sgInitialFunds cfg

    hasStakes :: Bool
    hasStakes = sgStaking cfg /= emptyGenesisStaking

    expectedTxCount :: Word64
    expectedTxCount = fromIntegral $ length (genesisTxos cfg) + if hasStakes then 1 else 0

    insertAction :: (MonadBaseControl IO m, MonadIO m) => ReaderT SqlBackend m (Either SyncNodeError ())
    insertAction = do
      ebid <- DB.queryBlockId (configGenesisHash cfg)
      case ebid of
        Right _ -> validateGenesisDistribution tracer networkName cfg expectedTxCount
        Left _ ->
          runExceptT $ do
            liftIO $ logInfo tracer "Inserting Shelley Genesis distribution"
            emeta <- lift DB.queryMeta
            case emeta of
              Right _ -> pure () -- Metadata from Shelley era already exists. TODO Validate metadata.
              Left _ -> do
                count <- lift DB.queryBlockCount
                when (count > 0) $
                  dbSyncNodeError $ "Shelley.insertValidateGenesisDist: Genesis data mismatch. count " <> textShow count
                void . lift $ DB.insertMeta $
                            DB.Meta
                              { DB.metaStartTime = configStartTime cfg
                              , DB.metaNetworkName = networkName
                              , DB.metaVersion = textShow version
                              }
            -- No reason to insert the artificial block if there are no funds or stakes definitions.
            when (hasInitialFunds || hasStakes) $ do
                -- Insert an 'artificial' Genesis block (with a genesis specific slot leader). We
                -- need this block to attach the genesis distribution transactions to.
                -- It would be nice to not need this artificial block, but that would
                -- require plumbing the Genesis.Config into 'insertByronBlockOrEBB'
                -- which would be a pain in the neck.
                slid <- lift . DB.insertSlotLeader $
                                DB.SlotLeader
                                  { DB.slotLeaderHash = genesisHashSlotLeader cfg
                                  , DB.slotLeaderPoolHashId = Nothing
                                  , DB.slotLeaderDescription = "Shelley Genesis slot leader"
                                  }
                -- We attach the Genesis Shelley Block after the block with the biggest Slot.
                -- In most cases this will simply be the Genesis Byron artificial Block,
                -- since this configuration is used for networks which start from Shelley.
                -- This means the previous block will have two blocks after it, resulting in a
                -- tree format, which is unavoidable.
                void . lift . DB.insertBlock $
                          DB.Block
                            { DB.blockHash = configGenesisHash cfg
                            , DB.blockEpochNo = Nothing
                            , DB.blockSlotNo = Nothing
                            , DB.blockEpochSlotNo = Nothing
                            , DB.blockBlockNo = fromIntegral $ unBlockNo DB.shelleyGenesisBlockNo
                            , DB.blockSlotLeaderId = slid
                            , DB.blockSize = 0
                            , DB.blockTime = configStartTime cfg
                            , DB.blockTxCount = expectedTxCount
                            -- Genesis block does not have a protocol version, so set this to '0'.
                            , DB.blockProtoMajor = 0
                            , DB.blockProtoMinor = 0
                            -- Shelley specific
                            , DB.blockVrfKey = Nothing
                            , DB.blockOpCert = Nothing
                            , DB.blockOpCertCounter = Nothing
                            }
                lift $ mapM_ (insertTxOuts tracer DB.shelleyGenesisBlockNo) $ genesisUtxOs cfg
                liftIO . logInfo tracer $ "Initial genesis distribution populated. Hash "
                                <> renderByteArray (configGenesisHash cfg)
                when hasStakes $
                  insertStaking tracer uninitiatedCache 0 cfg
                supply <- lift DB.queryTotalSupply
                liftIO $ logInfo tracer ("Total genesis supply of Ada: " <> DB.renderAda supply)

-- | Validate that the initial Genesis distribution in the DB matches the Genesis data.
validateGenesisDistribution
    :: (MonadBaseControl IO m, MonadIO m)
    => Trace IO Text -> Text -> ShelleyGenesis StandardShelley -> Word64
    -> ReaderT SqlBackend m (Either SyncNodeError ())
validateGenesisDistribution tracer networkName cfg expectedTxCount =
  runExceptT $ do
    liftIO $ logInfo tracer "Validating Genesis distribution"
    meta <- liftLookupFail "Shelley.validateGenesisDistribution" DB.queryMeta

    when (DB.metaStartTime meta /= configStartTime cfg) $
      dbSyncNodeError $ mconcat
            [ "Shelley: Mismatch chain start time. Config value "
            , textShow (configStartTime cfg)
            , " does not match DB value of ", textShow (DB.metaStartTime meta)
            ]

    when (DB.metaNetworkName meta /= networkName) $
      dbSyncNodeError $ mconcat
            [ "Shelley.validateGenesisDistribution: Provided network name "
            , networkName
            , " does not match DB value "
            , DB.metaNetworkName meta
            ]

    txCount <- lift DB.queryShelleyGenesisTxCount
    when (txCount /= expectedTxCount) $
      dbSyncNodeError $ mconcat
              [ "Shelley.validateGenesisDistribution: Expected initial block to have "
              , textShow expectedTxCount
              , " transactions but got "
              , textShow txCount
              ]
    totalSupply <- lift DB.queryShelleyGenesisSupply
    let expectedSupply = configGenesisSupply cfg
    when (expectedSupply /= totalSupply) $
      dbSyncNodeError  $ mconcat
         [ "Shelley.validateGenesisDistribution: Expected total supply to be "
         , textShow expectedSupply
         , " but got "
         , textShow totalSupply
         ]
    liftIO $ do
      logInfo tracer "Initial genesis distribution present and correct"
      logInfo tracer ("Total genesis supply of Ada: " <> DB.renderAda totalSupply)

-- -----------------------------------------------------------------------------

insertTxOuts
    :: (MonadBaseControl IO m, MonadIO m)
    => Trace IO Text -> BlockNo -> (ShelleyTx.TxIn (Crypto StandardShelley), Shelley.TxOut StandardShelley)
    -> ReaderT SqlBackend m ()
insertTxOuts trce blkNo (ShelleyTx.TxIn txInId _, txOut) = do
  -- Each address/value pair of the initial coin distribution comes from an artifical transaction
  -- with a hash generated by hashing the address.
  txId <- DB.insertTx $
            DB.Tx
              { DB.txHash = Generic.unTxHash txInId
              , DB.txBlockNo = fromIntegral $ unBlockNo blkNo
              , DB.txBlockIndex = 0
              , DB.txOutSum = Generic.coinToDbLovelace (txOutCoin txOut)
              , DB.txFee = DB.DbLovelace 0
              , DB.txDeposit = 0
              , DB.txSize = 0 -- Genesis distribution address to not have a size.
              , DB.txInvalidHereafter = Nothing
              , DB.txInvalidBefore = Nothing
              , DB.txValidContract = True
              , DB.txScriptSize = 0
              }
  void $ insertStakeAddressRefIfMissing trce uninitiatedCache blkNo (txOutAddress txOut)
  void . DB.insertTxOut $
            DB.TxOut
              { DB.txOutTxId = txId
              , DB.txOutIndex = 0
              , DB.txOutAddress = Generic.renderAddress (txOutAddress txOut)
              , DB.txOutAddressRaw = Ledger.serialiseAddr (txOutAddress txOut)
              , DB.txOutAddressHasScript = hasScript (txOutAddress txOut)
              , DB.txOutPaymentCred = Generic.maybePaymentCred (txOutAddress txOut)
              , DB.txOutStakeAddressId = Nothing -- No stake addresses in Shelley Genesis
              , DB.txOutValue = Generic.coinToDbLovelace (txOutCoin txOut)
              , DB.txOutDataHash = Nothing -- No output datum in Shelley Genesis
              , DB.txOutInlineDatumId = Nothing
              , DB.txOutReferenceScriptId = Nothing
              , DB.txOutBlockNo = fromIntegral $ unBlockNo blkNo
              }
  where
    txOutAddress :: Shelley.TxOut StandardShelley -> Ledger.Addr StandardCrypto
    txOutAddress (Shelley.TxOut out _) = out

    txOutCoin :: Shelley.TxOut StandardShelley -> Ledger.Coin
    txOutCoin (Shelley.TxOut _ coin) = coin

    hasScript addr = maybe False Generic.hasCredScript (Generic.getPaymentCred addr)

-- Insert pools and delegations coming from Genesis.
insertStaking
    :: (MonadBaseControl IO m, MonadIO m)
    => Trace IO Text -> Cache -> BlockNo -> ShelleyGenesis StandardShelley
    -> ExceptT SyncNodeError (ReaderT SqlBackend m) ()
insertStaking tracer cache blkNo genesis = do
  -- All Genesis staking comes from an artifical transaction
  -- with a hash generated by hashing the address.
  txId <- lift $ DB.insertTx $
            DB.Tx
              { DB.txHash = configGenesisStakingHash
              , DB.txBlockNo = fromIntegral $ unBlockNo blkNo
              , DB.txBlockIndex = 0
              , DB.txOutSum = DB.DbLovelace 0
              , DB.txFee = DB.DbLovelace 0
              , DB.txDeposit = 0
              , DB.txSize = 0
              , DB.txInvalidHereafter = Nothing
              , DB.txInvalidBefore = Nothing
              , DB.txValidContract = True
              , DB.txScriptSize = 0
              }
  let params = zip [0..] $ Map.elems (sgsPools $ sgStaking genesis)
  let network = sgNetworkId genesis
  forM_ params $ uncurry (insertPoolRegister tracer uninitiatedCache (const False) network 0 blkNo txId)
  let stakes = zip [0..] $ Map.toList (sgsStake $ sgStaking genesis)
  forM_ stakes $ \(n, (keyStaking, keyPool)) -> do
    insertStakeRegistration (EpochNo 0) blkNo txId (2 * n) (Generic.annotateStakingCred network (KeyHashObj keyStaking))
    insertDelegation cache network 0 0 blkNo (2 * n + 1) Nothing (KeyHashObj keyStaking) keyPool

-- -----------------------------------------------------------------------------

configGenesisHash :: ShelleyGenesis StandardShelley -> ByteString
configGenesisHash _ =  BS.take 32 ("Shelley Genesis Block Hash " <> BS.replicate 32 '\0')

genesisHashSlotLeader :: ShelleyGenesis StandardShelley -> ByteString
genesisHashSlotLeader _ = BS.take 28 ("Shelley Genesis SlotLeader Hash" <> BS.replicate 28 '\0')

configGenesisStakingHash :: ByteString
configGenesisStakingHash =  BS.take 32 ("Shelley Genesis Staking Tx Hash " <> BS.replicate 32 '\0')

configGenesisSupply :: ShelleyGenesis StandardShelley -> DB.Ada
configGenesisSupply =
  DB.word64ToAda . fromIntegral . sum . map (Ledger.unCoin . snd) . genesisTxoAssocList

genesisTxos :: ShelleyGenesis StandardShelley -> [Shelley.TxOut StandardShelley]
genesisTxos = map (uncurry Shelley.TxOut) . genesisTxoAssocList

genesisTxoAssocList :: ShelleyGenesis StandardShelley -> [(Ledger.Addr StandardCrypto, Ledger.Coin)]
genesisTxoAssocList =
    map (unTxOut . snd) . genesisUtxOs
  where
    unTxOut :: Shelley.TxOut StandardShelley -> (Ledger.Addr StandardCrypto, Ledger.Coin)
    unTxOut (Shelley.TxOut addr amount) = (addr, amount)

genesisUtxOs :: ShelleyGenesis StandardShelley -> [(ShelleyTx.TxIn (Crypto StandardShelley), Shelley.TxOut StandardShelley)]
genesisUtxOs =
    Map.toList . Shelley.unUTxO . Shelley.genesisUTxO

configStartTime :: ShelleyGenesis StandardShelley -> UTCTime
configStartTime = roundToMillseconds . Shelley.sgSystemStart

roundToMillseconds :: UTCTime -> UTCTime
roundToMillseconds (UTCTime day picoSecs) =
    UTCTime day (Time.picosecondsToDiffTime $ 1000000 * (picoSeconds `div` 1000000))
  where
    picoSeconds :: Integer
    picoSeconds = Time.diffTimeToPicoseconds picoSecs
