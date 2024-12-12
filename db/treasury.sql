DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'ItemRedeemed' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'ItemRedeemed';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'ItemPurchased' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'ItemPurchased';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'ItemLoaned' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'ItemLoaned';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'LoanReceived' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'LoanReceived';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'LoanItemSentBack' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'LoanItemSentBack';
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'BackingLoanPayedBack' 
          AND enumtypid = 'entity_type'::regtype
    ) THEN
        ALTER TYPE entity_type ADD VALUE 'BackingLoanPayedBack';
    END IF;
END $$;


CREATE TABLE IF NOT EXISTS "ItemRedeemed" (
  "id" TEXT PRIMARY KEY,
  "chain" VARCHAR(255) NOT NULL,
  "blockTimestamp" INT NOT NULL,
  "blockNumber" INT NOT NULL,
  "transactionHash" VARCHAR(255) NOT NULL,
  "treasuryAddress" VARCHAR(255) NOT NULL,
  "itemId" NUMERIC NOT NULL,
  "newTotalBacking" NUMERIC NOT NULL
);

CREATE TABLE IF NOT EXISTS "ItemPurchased" (
  "id" TEXT PRIMARY KEY,
  "chain" TEXT NOT NULL,
  "blockTimestamp" INT NOT NULL,
  "blockNumber" INT NOT NULL,
  "transactionHash" TEXT NOT NULL,
  "treasuryAddress" TEXT NOT NULL,
  "itemId" NUMERIC NOT NULL,
  "newTotalBacking" NUMERIC NOT NULL
);

CREATE TABLE IF NOT EXISTS "ItemLoaned" (
  "id" TEXT PRIMARY KEY,
  "chain" TEXT NOT NULL,
  "blockTimestamp" INT NOT NULL,
  "blockNumber" INT NOT NULL,
  "transactionHash" TEXT NOT NULL,
  "treasuryAddress" TEXT NOT NULL,
  "loanId" NUMERIC NOT NULL,
  "itemId" NUMERIC NOT NULL,
  "expiry" NUMERIC NOT NULL
);

CREATE TABLE IF NOT EXISTS "LoanReceived" (
  "id" TEXT PRIMARY KEY,
  "chain" TEXT NOT NULL,
  "blockTimestamp" INT NOT NULL,
  "blockNumber" INT NOT NULL,
  "transactionHash" TEXT NOT NULL,
  "treasuryAddress" TEXT NOT NULL,
  "loanId" NUMERIC NOT NULL,
  "ids" JSONB NOT NULL,
  "amount" NUMERIC NOT NULL,
  "expiry" NUMERIC NOT NULL
);

CREATE TABLE IF NOT EXISTS "LoanItemSentBack" (
  "id" TEXT PRIMARY KEY,
  "chain" TEXT NOT NULL,
  "blockTimestamp" INT NOT NULL,
  "blockNumber" INT NOT NULL,
  "transactionHash" TEXT NOT NULL,
  "treasuryAddress" TEXT NOT NULL,
  "loanId" NUMERIC NOT NULL,
  "newTotalBacking" NUMERIC NOT NULL
);

CREATE TABLE IF NOT EXISTS "BackingLoanPayedBack" (
  "id" TEXT PRIMARY KEY,
  "chain" TEXT NOT NULL,
  "blockTimestamp" INT NOT NULL,
  "blockNumber" INT NOT NULL,
  "transactionHash" TEXT NOT NULL,
  "treasuryAddress" TEXT NOT NULL,
  "loanId" NUMERIC NOT NULL,
  "newTotalBacking" NUMERIC NOT NULL
);
