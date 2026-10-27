-- Phase 6: scheduled maintenance, red-packet expiry/refunds and daily stats.

CREATE EXTENSION IF NOT EXISTS pg_cron;

ALTER TABLE public.redpackets
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_redpackets_expiry
  ON public.redpackets (expires_at)
  WHERE refunded_at IS NULL;

-- Refund every unclaimed share back to the sender. The escrow account was
-- credited when the packet was created and debited by each claim, so the
-- remaining escrow is exactly total_minor - sum(claims).
CREATE OR REPLACE FUNCTION public.expire_redpackets()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_packet public.redpackets;
  v_claimed BIGINT;
  v_remaining BIGINT;
  v_txn UUID;
  v_count INTEGER := 0;
BEGIN
  FOR v_packet IN
    SELECT * FROM public.redpackets
    WHERE expires_at <= NOW() AND refunded_at IS NULL
    ORDER BY expires_at
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT coalesce(sum(amount_minor), 0)
      INTO v_claimed
      FROM public.redpacket_claims
      WHERE redpacket_id = v_packet.id;

    v_remaining := v_packet.total_minor - v_claimed;
    IF v_remaining > 0 THEN
      INSERT INTO public.transactions
        (user_id, type, status, amount_minor, idempotency_key, meta)
      VALUES
        (v_packet.sender_id, 'redpacket', 'success', v_remaining,
         'redpacket-refund:' || v_packet.id::text,
         jsonb_build_object('redpacket_id', v_packet.id, 'refund', true))
      RETURNING id INTO v_txn;

      INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
      VALUES
        (v_txn, 'redpacket:' || v_packet.id::text, 'debit', v_remaining),
        (v_txn, v_packet.sender_id::text, 'credit', v_remaining);
    END IF;

    UPDATE public.redpackets
      SET refunded_at = NOW()
      WHERE id = v_packet.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.expire_redpackets() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_redpackets() TO service_role;

CREATE OR REPLACE FUNCTION public.purge_soft_deleted_media()
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  WITH purged AS (
    UPDATE public.messages
    SET media = NULL
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - INTERVAL '30 days'
      AND media IS NOT NULL
    RETURNING 1
  )
  SELECT count(*)::INTEGER FROM purged;
$$;
REVOKE ALL ON FUNCTION public.purge_soft_deleted_media() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_soft_deleted_media() TO service_role;

CREATE TABLE IF NOT EXISTS public.daily_stats (
  day DATE PRIMARY KEY,
  users INTEGER NOT NULL DEFAULT 0,
  messages INTEGER NOT NULL DEFAULT 0,
  transactions INTEGER NOT NULL DEFAULT 0,
  volume_minor BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.daily_stats ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.rebuild_daily_stats(p_day DATE DEFAULT CURRENT_DATE)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.daily_stats (day, users, messages, transactions, volume_minor)
  VALUES (
    p_day,
    (SELECT count(*) FROM public.profiles WHERE created_at::date <= p_day),
    (SELECT count(*) FROM public.messages WHERE created_at::date = p_day AND deleted_at IS NULL),
    (SELECT count(*) FROM public.transactions WHERE created_at::date = p_day),
    (SELECT coalesce(sum(amount_minor), 0) FROM public.transactions
      WHERE created_at::date = p_day AND status = 'success')
  )
  ON CONFLICT (day) DO UPDATE
    SET users = EXCLUDED.users,
        messages = EXCLUDED.messages,
        transactions = EXCLUDED.transactions,
        volume_minor = EXCLUDED.volume_minor;
END;
$$;
REVOKE ALL ON FUNCTION public.rebuild_daily_stats(DATE) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebuild_daily_stats(DATE) TO service_role;

-- Schedule idempotently. Supabase provides pg_cron; unscheduling first avoids
-- duplicate jobs when a migration is replayed locally.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ethiochat-expire-redpackets') THEN
    PERFORM cron.unschedule('ethiochat-expire-redpackets');
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ethiochat-purge-media') THEN
    PERFORM cron.unschedule('ethiochat-purge-media');
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'ethiochat-daily-stats') THEN
    PERFORM cron.unschedule('ethiochat-daily-stats');
  END IF;

  PERFORM cron.schedule(
    'ethiochat-expire-redpackets',
    '*/5 * * * *',
    'SELECT public.expire_redpackets();'
  );
  PERFORM cron.schedule(
    'ethiochat-purge-media',
    '15 3 * * *',
    'SELECT public.purge_soft_deleted_media();'
  );
  PERFORM cron.schedule(
    'ethiochat-daily-stats',
    '10 0 * * *',
    'SELECT public.rebuild_daily_stats(CURRENT_DATE - 1);'
  );
END;
$$;
