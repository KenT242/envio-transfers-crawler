--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Debian 16.4-1.pgdg120+1)
-- Dumped by pg_dump version 16.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hdb_catalog; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA hdb_catalog;


ALTER SCHEMA hdb_catalog OWNER TO postgres;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: contract_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.contract_type AS ENUM (
    'ERC721',
    'Treasury'
);


ALTER TYPE public.contract_type OWNER TO postgres;

--
-- Name: entity_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.entity_type AS ENUM (
    'NftTransfers',
    'RFVChanged'
);


ALTER TYPE public.entity_type OWNER TO postgres;

--
-- Name: gen_hasura_uuid(); Type: FUNCTION; Schema: hdb_catalog; Owner: postgres
--

CREATE FUNCTION hdb_catalog.gen_hasura_uuid() RETURNS uuid
    LANGUAGE sql
    AS $$select gen_random_uuid()$$;


ALTER FUNCTION hdb_catalog.gen_hasura_uuid() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: entity_history_filter; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.entity_history_filter (
    entity_id text NOT NULL,
    chain_id integer NOT NULL,
    old_val json,
    new_val json,
    block_number integer NOT NULL,
    block_timestamp integer NOT NULL,
    previous_block_number integer,
    log_index integer NOT NULL,
    previous_log_index integer NOT NULL,
    entity_type public.entity_type NOT NULL
);


ALTER TABLE public.entity_history_filter OWNER TO postgres;

--
-- Name: get_entity_history_filter(integer, integer, integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_entity_history_filter(start_timestamp integer, start_chain_id integer, start_block integer, start_log_index integer, end_timestamp integer, end_chain_id integer, end_block integer, end_log_index integer) RETURNS SETOF public.entity_history_filter
    LANGUAGE plpgsql STABLE
    AS $$
      BEGIN
          RETURN QUERY
          SELECT
              DISTINCT ON (coalesce(old.entity_id, new.entity_id))
              coalesce(old.entity_id, new.entity_id) as entity_id,
              new.chain_id as chain_id,
              coalesce(old.params, 'null') as old_val,
              coalesce(new.params, 'null') as new_val,
              new.block_number as block_number,
              old.block_number as previous_block_number,
              new.log_index as log_index,
              old.log_index as previous_log_index,
              new.entity_type as entity_type
          FROM
              entity_history old
              INNER JOIN entity_history next ON
              old.entity_id = next.entity_id
              AND old.entity_type = next.entity_type
              AND old.block_number = next.previous_block_number
              AND old.log_index = next.previous_log_index
            -- start <= next -- QUESTION: Should this be <?
              AND lt_entity_history(
                  start_timestamp,
                  start_chain_id,
                  start_block,
                  start_log_index,
                  next.block_timestamp,
                  next.chain_id,
                  next.block_number,
                  next.log_index
              )
            -- old < start -- QUESTION: Should this be <=?
              AND lt_entity_history(
                  old.block_timestamp,
                  old.chain_id,
                  old.block_number,
                  old.log_index,
                  start_timestamp,
                  start_chain_id,
                  start_block,
                  start_log_index
              )
            -- next <= end
              AND lte_entity_history(
                  next.block_timestamp,
                  next.chain_id,
                  next.block_number,
                  next.log_index,
                  end_timestamp,
                  end_chain_id,
                  end_block,
                  end_log_index
              )
              FULL OUTER JOIN entity_history new ON old.entity_id = new.entity_id
              AND new.entity_type = old.entity_type -- Assuming you want to check if entity types are the same
              AND lte_entity_history(
                  start_timestamp,
                  start_chain_id,
                  start_block,
                  start_log_index,
                  new.block_timestamp,
                  new.chain_id,
                  new.block_number,
                  new.log_index
              )
            -- new <= end
              AND lte_entity_history(
                  new.previous_block_timestamp,
                  new.previous_chain_id,
                  new.previous_block_number,
                  new.previous_log_index,
                  end_timestamp,
                  end_chain_id,
                  end_block,
                  end_log_index
              )
          WHERE
              lte_entity_history(
                  new.block_timestamp,
                  new.chain_id,
                  new.block_number,
                  new.log_index,
                  end_timestamp,
                  end_chain_id,
                  end_block,
                  end_log_index
              )
              AND lte_entity_history(
                  coalesce(old.block_timestamp, 0),
                  old.chain_id,
                  old.block_number,
                  old.log_index,
                  start_timestamp,
                  start_chain_id,
                  start_block,
                  start_log_index
              )
              AND lte_entity_history(
                  start_timestamp,
                  start_chain_id,
                  start_block,
                  start_log_index,
                  coalesce(new.block_timestamp, start_timestamp + 1),
                  new.chain_id,
                  new.block_number,
                  new.log_index
              )
          ORDER BY
              coalesce(old.entity_id, new.entity_id),
              new.block_number DESC,
              new.log_index DESC;
      END;
      $$;


ALTER FUNCTION public.get_entity_history_filter(start_timestamp integer, start_chain_id integer, start_block integer, start_log_index integer, end_timestamp integer, end_chain_id integer, end_block integer, end_log_index integer) OWNER TO postgres;

--
-- Name: insert_entity_history(integer, integer, integer, integer, json, public.entity_type, text, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.insert_entity_history(p_block_timestamp integer, p_chain_id integer, p_block_number integer, p_log_index integer, p_params json, p_entity_type public.entity_type, p_entity_id text, p_previous_block_timestamp integer DEFAULT NULL::integer, p_previous_chain_id integer DEFAULT NULL::integer, p_previous_block_number integer DEFAULT NULL::integer, p_previous_log_index integer DEFAULT NULL::integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
      DECLARE
          v_previous_record RECORD;
      BEGIN
          -- Check if previous values are not provided
          IF p_previous_block_timestamp IS NULL OR p_previous_chain_id IS NULL OR p_previous_block_number IS NULL OR p_previous_log_index IS NULL THEN
              -- Find the most recent record for the same entity_type and entity_id
              SELECT block_timestamp, chain_id, block_number, log_index INTO v_previous_record
              FROM entity_history
              WHERE entity_type = p_entity_type AND entity_id = p_entity_id
              ORDER BY block_timestamp DESC
              LIMIT 1;
              
              -- If a previous record exists, use its values
              IF FOUND THEN
                  p_previous_block_timestamp := v_previous_record.block_timestamp;
                  p_previous_chain_id := v_previous_record.chain_id;
                  p_previous_block_number := v_previous_record.block_number;
                  p_previous_log_index := v_previous_record.log_index;
              END IF;
          END IF;
          
          -- Insert the new record with either provided or looked-up previous values
          INSERT INTO entity_history (block_timestamp, chain_id, block_number, log_index, previous_block_timestamp, previous_chain_id, previous_block_number, previous_log_index, params, entity_type, entity_id)
          VALUES (p_block_timestamp, p_chain_id, p_block_number, p_log_index, p_previous_block_timestamp, p_previous_chain_id, p_previous_block_number, p_previous_log_index, p_params, p_entity_type, p_entity_id);
      END;
      $$;


ALTER FUNCTION public.insert_entity_history(p_block_timestamp integer, p_chain_id integer, p_block_number integer, p_log_index integer, p_params json, p_entity_type public.entity_type, p_entity_id text, p_previous_block_timestamp integer, p_previous_chain_id integer, p_previous_block_number integer, p_previous_log_index integer) OWNER TO postgres;

--
-- Name: lt_entity_history(integer, integer, integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lt_entity_history(block_timestamp integer, chain_id integer, block_number integer, log_index integer, compare_timestamp integer, compare_chain_id integer, compare_block integer, compare_log_index integer) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
    BEGIN
        RETURN (
            block_timestamp < compare_timestamp
            OR (
                block_timestamp = compare_timestamp
                AND (
                    chain_id < compare_chain_id
                    OR (
                        chain_id = compare_chain_id
                        AND (
                            block_number < compare_block
                            OR (
                                block_number = compare_block
                                AND log_index < compare_log_index
                            )
                        )
                    )
                )
            )
        );
    END;
    $$;


ALTER FUNCTION public.lt_entity_history(block_timestamp integer, chain_id integer, block_number integer, log_index integer, compare_timestamp integer, compare_chain_id integer, compare_block integer, compare_log_index integer) OWNER TO postgres;

--
-- Name: lte_entity_history(integer, integer, integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.lte_entity_history(block_timestamp integer, chain_id integer, block_number integer, log_index integer, compare_timestamp integer, compare_chain_id integer, compare_block integer, compare_log_index integer) RETURNS boolean
    LANGUAGE plpgsql STABLE
    AS $$
    BEGIN
        RETURN (
            block_timestamp < compare_timestamp
            OR (
                block_timestamp = compare_timestamp
                AND (
                    chain_id < compare_chain_id
                    OR (
                        chain_id = compare_chain_id
                        AND (
                            block_number < compare_block
                            OR (
                                block_number = compare_block
                                AND log_index <= compare_log_index
                            )
                        )
                    )
                )
            )
        );
    END;
    $$;


ALTER FUNCTION public.lte_entity_history(block_timestamp integer, chain_id integer, block_number integer, log_index integer, compare_timestamp integer, compare_chain_id integer, compare_block integer, compare_log_index integer) OWNER TO postgres;

--
-- Name: hdb_action_log; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_action_log (
    id uuid DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    action_name text,
    input_payload jsonb NOT NULL,
    request_headers jsonb NOT NULL,
    session_variables jsonb NOT NULL,
    response_payload jsonb,
    errors jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    response_received_at timestamp with time zone,
    status text NOT NULL,
    CONSTRAINT hdb_action_log_status_check CHECK ((status = ANY (ARRAY['created'::text, 'processing'::text, 'completed'::text, 'error'::text])))
);


ALTER TABLE hdb_catalog.hdb_action_log OWNER TO postgres;

--
-- Name: hdb_cron_event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_cron_event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.hdb_cron_event_invocation_logs OWNER TO postgres;

--
-- Name: hdb_cron_events; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_cron_events (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    trigger_name text NOT NULL,
    scheduled_time timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    CONSTRAINT valid_status CHECK ((status = ANY (ARRAY['scheduled'::text, 'locked'::text, 'delivered'::text, 'error'::text, 'dead'::text])))
);


ALTER TABLE hdb_catalog.hdb_cron_events OWNER TO postgres;

--
-- Name: hdb_metadata; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_metadata (
    id integer NOT NULL,
    metadata json NOT NULL,
    resource_version integer DEFAULT 1 NOT NULL
);


ALTER TABLE hdb_catalog.hdb_metadata OWNER TO postgres;

--
-- Name: hdb_scheduled_event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_scheduled_event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.hdb_scheduled_event_invocation_logs OWNER TO postgres;

--
-- Name: hdb_scheduled_events; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_scheduled_events (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    webhook_conf json NOT NULL,
    scheduled_time timestamp with time zone NOT NULL,
    retry_conf json,
    payload json,
    header_conf json,
    status text DEFAULT 'scheduled'::text NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    comment text,
    CONSTRAINT valid_status CHECK ((status = ANY (ARRAY['scheduled'::text, 'locked'::text, 'delivered'::text, 'error'::text, 'dead'::text])))
);


ALTER TABLE hdb_catalog.hdb_scheduled_events OWNER TO postgres;

--
-- Name: hdb_schema_notifications; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_schema_notifications (
    id integer NOT NULL,
    notification json NOT NULL,
    resource_version integer DEFAULT 1 NOT NULL,
    instance_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT hdb_schema_notifications_id_check CHECK ((id = 1))
);


ALTER TABLE hdb_catalog.hdb_schema_notifications OWNER TO postgres;

--
-- Name: hdb_version; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_version (
    hasura_uuid uuid DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    version text NOT NULL,
    upgraded_on timestamp with time zone NOT NULL,
    cli_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    console_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    ee_client_id text,
    ee_client_secret text
);


ALTER TABLE hdb_catalog.hdb_version OWNER TO postgres;

--
-- Name: NftTransfers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."NftTransfers" (
    block_number integer NOT NULL,
    block_timestamp integer NOT NULL,
    caller_address text NOT NULL,
    chain text NOT NULL,
    contract_address text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    from_address text NOT NULL,
    id text NOT NULL,
    quantity numeric NOT NULL,
    to_address text NOT NULL,
    token_id numeric NOT NULL,
    transaction_hash text NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    db_write_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."NftTransfers" OWNER TO postgres;

--
-- Name: RFVChanged; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."RFVChanged" (
    "blockNumber" integer NOT NULL,
    "blockTimestamp" integer NOT NULL,
    chain text NOT NULL,
    id text NOT NULL,
    "newRFV" numeric NOT NULL,
    "transactionHash" text NOT NULL,
    "treasuryAddress" text NOT NULL,
    db_write_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public."RFVChanged" OWNER TO postgres;

--
-- Name: chain_metadata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chain_metadata (
    chain_id integer NOT NULL,
    start_block integer NOT NULL,
    end_block integer,
    block_height integer NOT NULL,
    first_event_block_number integer,
    latest_processed_block integer,
    num_events_processed integer,
    is_hyper_sync boolean NOT NULL,
    num_batches_fetched integer NOT NULL,
    latest_fetched_block_number integer NOT NULL,
    timestamp_caught_up_to_head_or_endblock timestamp with time zone
);


ALTER TABLE public.chain_metadata OWNER TO postgres;

--
-- Name: dynamic_contract_registry; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dynamic_contract_registry (
    chain_id integer NOT NULL,
    event_id numeric NOT NULL,
    block_timestamp integer NOT NULL,
    contract_address text NOT NULL,
    contract_type public.contract_type NOT NULL
);


ALTER TABLE public.dynamic_contract_registry OWNER TO postgres;

--
-- Name: end_of_block_range_scanned_data; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.end_of_block_range_scanned_data (
    chain_id integer NOT NULL,
    block_timestamp integer NOT NULL,
    block_number integer NOT NULL,
    block_hash text NOT NULL
);


ALTER TABLE public.end_of_block_range_scanned_data OWNER TO postgres;

--
-- Name: entity_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.entity_history (
    entity_id text NOT NULL,
    block_timestamp integer NOT NULL,
    chain_id integer NOT NULL,
    block_number integer NOT NULL,
    log_index integer NOT NULL,
    entity_type public.entity_type NOT NULL,
    params json,
    previous_block_timestamp integer,
    previous_chain_id integer,
    previous_block_number integer,
    previous_log_index integer
);


ALTER TABLE public.entity_history OWNER TO postgres;

--
-- Name: event_sync_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.event_sync_state (
    chain_id integer NOT NULL,
    block_number integer NOT NULL,
    log_index integer NOT NULL,
    block_timestamp integer NOT NULL
);


ALTER TABLE public.event_sync_state OWNER TO postgres;

--
-- Name: persisted_state; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.persisted_state (
    id integer NOT NULL,
    envio_version text NOT NULL,
    config_hash text NOT NULL,
    schema_hash text NOT NULL,
    handler_files_hash text NOT NULL,
    abi_files_hash text NOT NULL
);


ALTER TABLE public.persisted_state OWNER TO postgres;

--
-- Name: persisted_state_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.persisted_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.persisted_state_id_seq OWNER TO postgres;

--
-- Name: persisted_state_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.persisted_state_id_seq OWNED BY public.persisted_state.id;


--
-- Name: raw_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raw_events (
    chain_id integer NOT NULL,
    event_id numeric NOT NULL,
    event_name text NOT NULL,
    contract_name text NOT NULL,
    block_number integer NOT NULL,
    log_index integer NOT NULL,
    src_address text NOT NULL,
    block_hash text NOT NULL,
    block_timestamp integer NOT NULL,
    block_fields json NOT NULL,
    transaction_fields json NOT NULL,
    params json NOT NULL,
    db_write_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.raw_events OWNER TO postgres;

--
-- Name: persisted_state id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persisted_state ALTER COLUMN id SET DEFAULT nextval('public.persisted_state_id_seq'::regclass);


--
-- Name: hdb_action_log hdb_action_log_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_action_log
    ADD CONSTRAINT hdb_action_log_pkey PRIMARY KEY (id);


--
-- Name: hdb_cron_event_invocation_logs hdb_cron_event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_event_invocation_logs
    ADD CONSTRAINT hdb_cron_event_invocation_logs_pkey PRIMARY KEY (id);


--
-- Name: hdb_cron_events hdb_cron_events_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_events
    ADD CONSTRAINT hdb_cron_events_pkey PRIMARY KEY (id);


--
-- Name: hdb_metadata hdb_metadata_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_metadata
    ADD CONSTRAINT hdb_metadata_pkey PRIMARY KEY (id);


--
-- Name: hdb_metadata hdb_metadata_resource_version_key; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_metadata
    ADD CONSTRAINT hdb_metadata_resource_version_key UNIQUE (resource_version);


--
-- Name: hdb_scheduled_event_invocation_logs hdb_scheduled_event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_event_invocation_logs
    ADD CONSTRAINT hdb_scheduled_event_invocation_logs_pkey PRIMARY KEY (id);


--
-- Name: hdb_scheduled_events hdb_scheduled_events_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_events
    ADD CONSTRAINT hdb_scheduled_events_pkey PRIMARY KEY (id);


--
-- Name: hdb_schema_notifications hdb_schema_notifications_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_schema_notifications
    ADD CONSTRAINT hdb_schema_notifications_pkey PRIMARY KEY (id);


--
-- Name: hdb_version hdb_version_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_version
    ADD CONSTRAINT hdb_version_pkey PRIMARY KEY (hasura_uuid);


--
-- Name: NftTransfers NftTransfers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."NftTransfers"
    ADD CONSTRAINT "NftTransfers_pkey" PRIMARY KEY (id);


--
-- Name: RFVChanged RFVChanged_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."RFVChanged"
    ADD CONSTRAINT "RFVChanged_pkey" PRIMARY KEY (id);


--
-- Name: chain_metadata chain_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chain_metadata
    ADD CONSTRAINT chain_metadata_pkey PRIMARY KEY (chain_id);


--
-- Name: dynamic_contract_registry dynamic_contract_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dynamic_contract_registry
    ADD CONSTRAINT dynamic_contract_registry_pkey PRIMARY KEY (chain_id, contract_address);


--
-- Name: end_of_block_range_scanned_data end_of_block_range_scanned_data_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.end_of_block_range_scanned_data
    ADD CONSTRAINT end_of_block_range_scanned_data_pkey PRIMARY KEY (chain_id, block_number);


--
-- Name: entity_history_filter entity_history_filter_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_history_filter
    ADD CONSTRAINT entity_history_filter_pkey PRIMARY KEY (entity_id, chain_id, block_number, block_timestamp, log_index, previous_log_index, entity_type);


--
-- Name: entity_history entity_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.entity_history
    ADD CONSTRAINT entity_history_pkey PRIMARY KEY (entity_id, block_timestamp, chain_id, block_number, log_index, entity_type);


--
-- Name: event_sync_state event_sync_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.event_sync_state
    ADD CONSTRAINT event_sync_state_pkey PRIMARY KEY (chain_id);


--
-- Name: persisted_state persisted_state_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.persisted_state
    ADD CONSTRAINT persisted_state_pkey PRIMARY KEY (id);


--
-- Name: raw_events raw_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raw_events
    ADD CONSTRAINT raw_events_pkey PRIMARY KEY (chain_id, event_id);


--
-- Name: hdb_cron_event_invocation_event_id; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE INDEX hdb_cron_event_invocation_event_id ON hdb_catalog.hdb_cron_event_invocation_logs USING btree (event_id);


--
-- Name: hdb_cron_event_status; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE INDEX hdb_cron_event_status ON hdb_catalog.hdb_cron_events USING btree (status);


--
-- Name: hdb_cron_events_unique_scheduled; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE UNIQUE INDEX hdb_cron_events_unique_scheduled ON hdb_catalog.hdb_cron_events USING btree (trigger_name, scheduled_time) WHERE (status = 'scheduled'::text);


--
-- Name: hdb_scheduled_event_status; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE INDEX hdb_scheduled_event_status ON hdb_catalog.hdb_scheduled_events USING btree (status);


--
-- Name: hdb_version_one_row; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE UNIQUE INDEX hdb_version_one_row ON hdb_catalog.hdb_version USING btree (((version IS NOT NULL)));


--
-- Name: entity_history_entity_type_entity_id_block_timestamp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX entity_history_entity_type_entity_id_block_timestamp ON public.entity_history USING btree (entity_type, entity_id, block_timestamp);


--
-- Name: hdb_cron_event_invocation_logs hdb_cron_event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_event_invocation_logs
    ADD CONSTRAINT hdb_cron_event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.hdb_cron_events(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: hdb_scheduled_event_invocation_logs hdb_scheduled_event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_event_invocation_logs
    ADD CONSTRAINT hdb_scheduled_event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.hdb_scheduled_events(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

