-- Phase 3: Wallet with double-entry ledger (immutable)

CREATE TABLE IF NOT EXISTS public.wallets (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  currency TEXT NOT NULL DEFAULT 'ETB',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Immutable double-entry ledger
CREATE TABLE IF NOT EXISTS public.ledger_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  txn_id UUID NOT NULL,
  account TEXT NOT NULL, -- user_id or system account
  direction TEXT NOT NULL CHECK (direction IN ('debit','credit')),
  amount_minor BIGINT NOT NULL CHECK (amount_minor >= 0),
  currency TEXT NOT NULL DEFAULT 'ETB',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ledger_txn ON public.ledger_entries (txn_id);
CREATE INDEX IF NOT EXISTS idx_ledger_account ON public.ledger_entries (account, created_at);

CREATE TABLE IF NOT EXISTS public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  type TEXT NOT NULL CHECK (type IN ('topup','p2p','redpacket','merchant','withdraw','bill')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','success','failed','reversed')),
  amount_minor BIGINT NOT NULL,
  fee_minor BIGINT DEFAULT 0,
  provider TEXT,
  provider_ref TEXT,
  idempotency_key TEXT UNIQUE,
  meta JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.redpackets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  conversation_id UUID REFERENCES public.conversations(id),
  total_minor BIGINT NOT NULL CHECK (total_minor > 0),
  count INTEGER NOT NULL CHECK (count > 0),
  mode TEXT NOT NULL DEFAULT 'random' CHECK (mode IN ('random','equal')),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.redpacket_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  redpacket_id UUID NOT NULL REFERENCES public.redpackets(id) ON DELETE CASCADE,
  claimer_id UUID NOT NULL REFERENCES auth.users(id),
  amount_minor BIGINT NOT NULL,
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (redpacket_id, claimer_id)
);

CREATE TABLE IF NOT EXISTS public.pin_secrets (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  pin_hash TEXT NOT NULL,
  attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.kyc (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier INTEGER NOT NULL DEFAULT 0 CHECK (tier IN (0,1,2)),
  status TEXT DEFAULT 'pending',
  data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redpackets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redpacket_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pin_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc ENABLE ROW LEVEL SECURITY;

-- Wallets: own only
CREATE POLICY wallets_own ON public.wallets FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
-- Ledger: read own entries only; no insert/update/delete via RLS for users (service role only)
CREATE POLICY ledger_read_own ON public.ledger_entries FOR SELECT USING (account = auth.uid()::text);
-- Transactions
CREATE POLICY transactions_own ON public.transactions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY transactions_insert_own ON public.transactions FOR INSERT WITH CHECK (user_id = auth.uid());
-- Red packets
CREATE POLICY redpackets_select ON public.redpackets FOR SELECT USING (true);
CREATE POLICY redpackets_insert ON public.redpackets FOR INSERT WITH CHECK (sender_id = auth.uid());
CREATE POLICY redpacket_claims_all ON public.redpacket_claims FOR ALL USING (claimer_id = auth.uid()) WITH CHECK (claimer_id = auth.uid());
-- PIN/KYC
CREATE POLICY pin_own ON public.pin_secrets FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY kyc_own ON public.kyc FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Prevent updates/deletes on ledger_entries
REVOKE UPDATE, DELETE ON public.ledger_entries FROM anon, authenticated;
