-- Persistent generated migration.

CREATE FUNCTION migrate() RETURNS void AS $$
DECLARE
  next_version int ;
BEGIN
  SELECT stage_two + 1 INTO next_version FROM schema_version ;
  IF next_version = 1 THEN
    EXECUTE 'ALTER TABLE "schema_version" ALTER COLUMN "id" TYPE INT8' ;
    EXECUTE 'CREATe TABLE "pool_hash"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash_raw" hash28type NOT NULL,"view" VARCHAR NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_hash" ADD CONSTRAINT "unique_pool_hash" UNIQUE("hash_raw")' ;
    EXECUTE 'CREATe TABLE "slot_leader"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash28type NOT NULL,"pool_hash_id" INT8 NULL,"description" VARCHAR NOT NULL)' ;
    EXECUTE 'ALTER TABLE "slot_leader" ADD CONSTRAINT "unique_slot_leader" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "block"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash32type NOT NULL,"epoch_no" word31type NULL,"slot_no" word63type NULL,"epoch_slot_no" word31type NULL,"block_no" bigint NOT NULL,"slot_leader_id" INT8 NOT NULL,"size" word31type NOT NULL,"time" timestamp NOT NULL,"tx_count" INT8 NOT NULL,"proto_major" word31type NOT NULL,"proto_minor" word31type NOT NULL,"vrf_key" VARCHAR NULL,"op_cert" hash32type NULL,"op_cert_counter" word63type NULL)' ;
    EXECUTE 'ALTER TABLE "block" ADD CONSTRAINT "unique_block" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "tx"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash32type NOT NULL,"block_no" bigint NOT NULL,"block_index" word31type NOT NULL,"out_sum" lovelace NOT NULL,"fee" lovelace NOT NULL,"deposit" INT8 NOT NULL,"size" word31type NOT NULL,"invalid_before" word64type NULL,"invalid_hereafter" word64type NULL,"valid_contract" BOOLEAN NOT NULL,"script_size" word31type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "tx" ADD CONSTRAINT "unique_tx" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "stake_address"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash_raw" addr29type NOT NULL,"view" VARCHAR NOT NULL,"script_hash" hash28type NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "stake_address" ADD CONSTRAINT "unique_stake_address" UNIQUE("hash_raw")' ;
    EXECUTE 'CREATe TABLE "tx_out"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_id" INT8 NOT NULL,"index" txindex NOT NULL,"address" VARCHAR NOT NULL,"address_raw" BYTEA NOT NULL,"address_has_script" BOOLEAN NOT NULL,"payment_cred" hash28type NULL,"stake_address_id" INT8 NULL,"value" lovelace NOT NULL,"data_hash" hash32type NULL,"inline_datum_id" INT8 NULL,"reference_script_id" INT8 NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "tx_out" ADD CONSTRAINT "unique_txout" UNIQUE("tx_id","index")' ;
    EXECUTE 'CREATe TABLE "collateral_tx_out"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_id" INT8 NOT NULL,"index" txindex NOT NULL,"address" VARCHAR NOT NULL,"address_raw" BYTEA NOT NULL,"address_has_script" BOOLEAN NOT NULL,"payment_cred" hash28type NULL,"stake_address_id" INT8 NULL,"value" lovelace NOT NULL,"data_hash" hash32type NULL,"multi_assets_descr" VARCHAR NOT NULL,"inline_datum_id" INT8 NULL,"reference_script_id" INT8 NULL)' ;
    EXECUTE 'ALTER TABLE "collateral_tx_out" ADD CONSTRAINT "unique_col_txout" UNIQUE("tx_id","index")' ;
    EXECUTE 'CREATe TABLE "tx_in"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_in_id" INT8 NOT NULL,"tx_out_id" INT8 NOT NULL,"tx_out_index" txindex NOT NULL,"redeemer_id" INT8 NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "tx_in" ADD CONSTRAINT "unique_txin" UNIQUE("tx_out_id","tx_out_index")' ;
    EXECUTE 'CREATe TABLE "collateral_tx_in"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_in_id" INT8 NOT NULL,"tx_out_id" INT8 NOT NULL,"tx_out_index" txindex NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "collateral_tx_in" ADD CONSTRAINT "unique_col_txin" UNIQUE("tx_in_id","tx_out_id","tx_out_index")' ;
    EXECUTE 'CREATe TABLE "reference_tx_in"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_in_id" INT8 NOT NULL,"tx_out_id" INT8 NOT NULL,"tx_out_index" txindex NOT NULL)' ;
    EXECUTE 'ALTER TABLE "reference_tx_in" ADD CONSTRAINT "unique_ref_txin" UNIQUE("tx_in_id","tx_out_id","tx_out_index")' ;
    EXECUTE 'CREATe TABLE "meta"("id" SERIAL8  PRIMARY KEY UNIQUE,"start_time" timestamp NOT NULL,"network_name" VARCHAR NOT NULL,"version" VARCHAR NOT NULL)' ;
    EXECUTE 'ALTER TABLE "meta" ADD CONSTRAINT "unique_meta" UNIQUE("start_time")' ;
    EXECUTE 'CREATe TABLE "epoch"("id" SERIAL8  PRIMARY KEY UNIQUE,"out_sum" word128type NOT NULL,"fees" lovelace NOT NULL,"tx_count" word31type NOT NULL,"blk_count" word31type NOT NULL,"no" word31type NOT NULL,"start_time" timestamp NOT NULL,"end_time" timestamp NOT NULL)' ;
    EXECUTE 'ALTER TABLE "epoch" ADD CONSTRAINT "unique_epoch" UNIQUE("no")' ;
    EXECUTE 'CREATe TABLE "ada_pots"("id" SERIAL8  PRIMARY KEY UNIQUE,"slot_no" word63type NOT NULL,"epoch_no" word31type NOT NULL,"treasury" lovelace NOT NULL,"reserves" lovelace NOT NULL,"rewards" lovelace NOT NULL,"utxo" lovelace NOT NULL,"deposits" lovelace NOT NULL,"fees" lovelace NOT NULL,"block_no" word63type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "ada_pots" ADD CONSTRAINT "unique_ada_pots" UNIQUE("block_no")' ;
    EXECUTE 'CREATe TABLE "pool_metadata_ref"("id" SERIAL8  PRIMARY KEY UNIQUE,"pool_id" INT8 NOT NULL,"url" VARCHAR NOT NULL,"hash" hash32type NOT NULL,"registered_tx_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_metadata_ref" ADD CONSTRAINT "unique_pool_metadata_ref" UNIQUE("pool_id","url","hash")' ;
    EXECUTE 'CREATe TABLE "pool_update"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"vrf_key_hash" hash32type NOT NULL,"pledge" lovelace NOT NULL,"reward_addr_id" INT8 NOT NULL,"active_epoch_no" INT8 NOT NULL,"meta_id" INT8 NULL,"margin" DOUBLE PRECISION NOT NULL,"fixed_cost" lovelace NOT NULL,"registered_tx_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_update" ADD CONSTRAINT "unique_pool_update" UNIQUE("registered_tx_id","cert_index")' ;
    EXECUTE 'CREATe TABLE "pool_owner"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"pool_update_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_owner" ADD CONSTRAINT "unique_pool_owner" UNIQUE("addr_id","pool_update_id")' ;
    EXECUTE 'CREATe TABLE "pool_retire"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"announced_tx_id" INT8 NOT NULL,"retiring_epoch" word31type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_retire" ADD CONSTRAINT "unique_pool_retiring" UNIQUE("announced_tx_id","cert_index")' ;
    EXECUTE 'CREATe TABLE "pool_relay"("id" SERIAL8  PRIMARY KEY UNIQUE,"update_id" INT8 NOT NULL,"ipv4" VARCHAR NULL,"ipv6" VARCHAR NULL,"dns_name" VARCHAR NULL,"dns_srv_name" VARCHAR NULL,"port" INT4 NULL)' ;
    EXECUTE 'ALTER TABLE "pool_relay" ADD CONSTRAINT "unique_pool_relay" UNIQUE("update_id","ipv4","ipv6","dns_name")' ;
    EXECUTE 'CREATe TABLE "stake_registration"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"tx_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"epoch_no" word31type NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "stake_registration" ADD CONSTRAINT "unique_stake_registration" UNIQUE("tx_id","cert_index")' ;
    EXECUTE 'CREATe TABLE "stake_deregistration"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"tx_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"epoch_no" word31type NOT NULL,"block_no" bigint NOT NULL,"redeemer_id" INT8 NULL)' ;
    EXECUTE 'ALTER TABLE "stake_deregistration" ADD CONSTRAINT "unique_stake_deregistration" UNIQUE("tx_id","cert_index")' ;
    EXECUTE 'CREATe TABLE "delegation"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"pool_hash_id" INT8 NOT NULL,"active_epoch_no" INT8 NOT NULL,"block_no" bigint NOT NULL,"slot_no" word63type NOT NULL,"redeemer_id" INT8 NULL)' ;
    EXECUTE 'ALTER TABLE "delegation" ADD CONSTRAINT "unique_delegation" UNIQUE("block_no","cert_index")' ;
    EXECUTE 'CREATe TABLE "tx_metadata"("id" SERIAL8  PRIMARY KEY UNIQUE,"key" word64type NOT NULL,"json" jsonb NULL,"bytes" bytea NOT NULL,"tx_id" INT8 NOT NULL,"block_no" word63type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "tx_metadata" ADD CONSTRAINT "unique_tx_metadata" UNIQUE("key","tx_id")' ;
    EXECUTE 'CREATe TABLE "reward"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"type" rewardtype NOT NULL,"amount" lovelace NOT NULL,"earned_epoch" INT8 NOT NULL,"spendable_epoch" INT8 NOT NULL,"pool_id" INT8 NULL)' ;
    EXECUTE 'ALTER TABLE "reward" ADD CONSTRAINT "unique_reward" UNIQUE("addr_id","type","earned_epoch","pool_id")' ;
    EXECUTE 'CREATe TABLE "withdrawal"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"amount" lovelace NOT NULL,"redeemer_id" INT8 NULL,"tx_id" INT8 NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "withdrawal" ADD CONSTRAINT "unique_withdrawal" UNIQUE("addr_id","tx_id")' ;
    EXECUTE 'CREATe TABLE "epoch_stake"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"pool_id" INT8 NOT NULL,"amount" lovelace NOT NULL,"epoch_no" word31type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "epoch_stake" ADD CONSTRAINT "unique_stake" UNIQUE("epoch_no","addr_id","pool_id")' ;
    EXECUTE 'CREATe TABLE "treasury"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"tx_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"amount" int65type NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "treasury" ADD CONSTRAINT "unique_treasury" UNIQUE("addr_id","block_no","tx_id","cert_index")' ;
    EXECUTE 'CREATe TABLE "reserve"("id" SERIAL8  PRIMARY KEY UNIQUE,"addr_id" INT8 NOT NULL,"tx_id" INT8 NOT NULL,"cert_index" INT4 NOT NULL,"amount" int65type NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "reserve" ADD CONSTRAINT "unique_reserves" UNIQUE("addr_id","block_no","tx_id","cert_index")' ;
    EXECUTE 'CREATe TABLE "pot_transfer"("id" SERIAL8  PRIMARY KEY UNIQUE,"cert_index" INT4 NOT NULL,"treasury" int65type NOT NULL,"reserves" int65type NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pot_transfer" ADD CONSTRAINT "unique_pot_transfer" UNIQUE("block_no","cert_index")' ;
    EXECUTE 'CREATe TABLE "epoch_sync_time"("id" SERIAL8  PRIMARY KEY UNIQUE,"no" INT8 NOT NULL,"seconds" word63type NOT NULL,"state" syncstatetype NOT NULL)' ;
    EXECUTE 'ALTER TABLE "epoch_sync_time" ADD CONSTRAINT "unique_epoch_sync_time" UNIQUE("no")' ;
    EXECUTE 'CREATe TABLE "multi_asset"("id" SERIAL8  PRIMARY KEY UNIQUE,"policy" hash28type NOT NULL,"name" asset32type NOT NULL,"fingerprint" VARCHAR NOT NULL)' ;
    EXECUTE 'ALTER TABLE "multi_asset" ADD CONSTRAINT "unique_multi_asset" UNIQUE("policy","name")' ;
    EXECUTE 'CREATe TABLE "ma_tx_mint"("id" SERIAL8  PRIMARY KEY UNIQUE,"ident" INT8 NOT NULL,"quantity" int65type NOT NULL,"tx_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "ma_tx_mint" ADD CONSTRAINT "unique_ma_tx_mint" UNIQUE("ident","tx_id")' ;
    EXECUTE 'CREATe TABLE "ma_tx_out"("id" SERIAL8  PRIMARY KEY UNIQUE,"ident" INT8 NOT NULL,"quantity" word64type NOT NULL,"tx_out_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "ma_tx_out" ADD CONSTRAINT "unique_ma_tx_out" UNIQUE("ident","tx_out_id")' ;
    EXECUTE 'CREATe TABLE "redeemer"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_id" INT8 NOT NULL,"unit_mem" word63type NOT NULL,"unit_steps" word63type NOT NULL,"fee" lovelace NULL,"purpose" scriptpurposetype NOT NULL,"index" word31type NOT NULL,"script_hash" hash28type NULL,"redeemer_data_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "redeemer" ADD CONSTRAINT "unique_redeemer" UNIQUE("tx_id","purpose","index")' ;
    EXECUTE 'CREATe TABLE "script"("id" SERIAL8  PRIMARY KEY UNIQUE,"tx_id" INT8 NOT NULL,"hash" hash28type NOT NULL,"type" scripttype NOT NULL,"json" jsonb NULL,"bytes" bytea NULL,"serialised_size" word31type NULL)' ;
    EXECUTE 'ALTER TABLE "script" ADD CONSTRAINT "unique_script" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "datum"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash32type NOT NULL,"tx_id" INT8 NOT NULL,"value" jsonb NULL,"bytes" bytea NOT NULL)' ;
    EXECUTE 'ALTER TABLE "datum" ADD CONSTRAINT "unique_datum" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "redeemer_data"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash32type NOT NULL,"tx_id" INT8 NOT NULL,"value" jsonb NULL,"bytes" bytea NOT NULL)' ;
    EXECUTE 'ALTER TABLE "redeemer_data" ADD CONSTRAINT "unique_redeemer_data" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "extra_key_witness"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash28type NOT NULL,"tx_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "extra_key_witness" ADD CONSTRAINT "unique_witness" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "param_proposal"("id" SERIAL8  PRIMARY KEY UNIQUE,"epoch_no" word31type NOT NULL,"key" hash28type NOT NULL,"min_fee_a" word64type NULL,"min_fee_b" word64type NULL,"max_block_size" word64type NULL,"max_tx_size" word64type NULL,"max_bh_size" word64type NULL,"key_deposit" lovelace NULL,"pool_deposit" lovelace NULL,"max_epoch" word64type NULL,"optimal_pool_count" word64type NULL,"influence" DOUBLE PRECISION NULL,"monetary_expand_rate" DOUBLE PRECISION NULL,"treasury_growth_rate" DOUBLE PRECISION NULL,"decentralisation" DOUBLE PRECISION NULL,"entropy" hash32type NULL,"protocol_major" word31type NULL,"protocol_minor" word31type NULL,"min_utxo_value" lovelace NULL,"min_pool_cost" lovelace NULL,"coins_per_utxo_size" lovelace NULL,"cost_model_id" INT8 NULL,"price_mem" DOUBLE PRECISION NULL,"price_step" DOUBLE PRECISION NULL,"max_tx_ex_mem" word64type NULL,"max_tx_ex_steps" word64type NULL,"max_block_ex_mem" word64type NULL,"max_block_ex_steps" word64type NULL,"max_val_size" word64type NULL,"collateral_percent" word31type NULL,"max_collateral_inputs" word31type NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "param_proposal" ADD CONSTRAINT "unique_param_proposal" UNIQUE("key","block_no")' ;
    EXECUTE 'CREATe TABLE "epoch_param"("id" SERIAL8  PRIMARY KEY UNIQUE,"epoch_no" word31type NOT NULL,"min_fee_a" word31type NOT NULL,"min_fee_b" word31type NOT NULL,"max_block_size" word31type NOT NULL,"max_tx_size" word31type NOT NULL,"max_bh_size" word31type NOT NULL,"key_deposit" lovelace NOT NULL,"pool_deposit" lovelace NOT NULL,"max_epoch" word31type NOT NULL,"optimal_pool_count" word31type NOT NULL,"influence" DOUBLE PRECISION NOT NULL,"monetary_expand_rate" DOUBLE PRECISION NOT NULL,"treasury_growth_rate" DOUBLE PRECISION NOT NULL,"decentralisation" DOUBLE PRECISION NOT NULL,"extra_entropy" hash32type NULL,"protocol_major" word31type NOT NULL,"protocol_minor" word31type NOT NULL,"min_utxo_value" lovelace NOT NULL,"min_pool_cost" lovelace NOT NULL,"nonce" hash32type NULL,"coins_per_utxo_word" lovelace NULL,"cost_model_id" INT8 NULL,"price_mem" DOUBLE PRECISION NULL,"price_step" DOUBLE PRECISION NULL,"max_tx_ex_mem" word64type NULL,"max_tx_ex_steps" word64type NULL,"max_block_ex_mem" word64type NULL,"max_block_ex_steps" word64type NULL,"max_val_size" word64type NULL,"collateral_percent" word31type NULL,"max_collateral_inputs" word31type NULL)' ;
    EXECUTE 'ALTER TABLE "epoch_param" ADD CONSTRAINT "unique_epoch_param" UNIQUE("epoch_no")' ;
    EXECUTE 'CREATe TABLE "cost_model"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash" hash32type NOT NULL,"costs" jsonb NOT NULL,"block_no" bigint NOT NULL)' ;
    EXECUTE 'ALTER TABLE "cost_model" ADD CONSTRAINT "unique_cost_model" UNIQUE("hash")' ;
    EXECUTE 'CREATe TABLE "pool_offline_data"("id" SERIAL8  PRIMARY KEY UNIQUE,"pool_id" INT8 NOT NULL,"ticker_name" VARCHAR NOT NULL,"hash" hash32type NOT NULL,"json" jsonb NOT NULL,"bytes" bytea NOT NULL,"pmr_id" INT8 NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_offline_data" ADD CONSTRAINT "unique_pool_offline_data" UNIQUE("pool_id","hash")' ;
    EXECUTE 'CREATe TABLE "pool_offline_fetch_error"("id" SERIAL8  PRIMARY KEY UNIQUE,"pool_id" INT8 NOT NULL,"fetch_time" timestamp NOT NULL,"pmr_id" INT8 NOT NULL,"fetch_error" VARCHAR NOT NULL,"retry_count" word31type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "pool_offline_fetch_error" ADD CONSTRAINT "unique_pool_offline_fetch_error" UNIQUE("pool_id","fetch_time","retry_count")' ;
    EXECUTE 'CREATe TABLE "reserved_pool_ticker"("id" SERIAL8  PRIMARY KEY UNIQUE,"name" VARCHAR NOT NULL,"pool_hash" hash28type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "reserved_pool_ticker" ADD CONSTRAINT "unique_reserved_pool_ticker" UNIQUE("name")' ;
    EXECUTE 'CREATe TABLE "delisted_pool"("id" SERIAL8  PRIMARY KEY UNIQUE,"hash_raw" hash28type NOT NULL)' ;
    EXECUTE 'ALTER TABLE "delisted_pool" ADD CONSTRAINT "unique_delisted_pool" UNIQUE("hash_raw")' ;
    -- Hand written SQL statements can be added here.
    UPDATE schema_version SET stage_two = next_version ;
    RAISE NOTICE 'DB has been migrated to stage_two version %', next_version ;
  END IF ;
END ;
$$ LANGUAGE plpgsql ;

SELECT migrate() ;

DROP FUNCTION migrate() ;
