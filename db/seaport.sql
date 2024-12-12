DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'OrderFulfilled' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'OrderFulfilled';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'NftSales' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'NftSales';
    END IF;
END $$;


CREATE TABLE public."NftSales" (
    id TEXT PRIMARY KEY,
    chain text NOT NULL,
    transaction_hash text NOT NULL,
    log_index integer NOT NULL,
    order_hash  text NOT NULL, 
    contract_address  text NOT NULL, 
    token_id  text NOT NULL, 
    sale_token  text NOT NULL,   
    sale_amount  numeric NOT NULL,
    offerer  text NOT NULL,  
    recipient  text NOT NULL,    
    block_number  integer NOT NULL,
    block_timestamp  integer NOT NULL,
    zone  text NOT NULL, 
    marketplace  text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    db_write_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);