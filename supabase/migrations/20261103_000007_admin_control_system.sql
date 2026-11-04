-- Admin control system: server-verified roles, workflow data, and audit trail.

CREATE TABLE IF NOT EXISTS public.staff_roles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'moderator', 'support', 'finance', 'content')),
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.staff_roles ENABLE ROW LEVEL SECURITY;

INSERT INTO public.staff_roles (user_id, role)
SELECT id, 'admin' FROM public.profiles WHERE role = 'admin'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.staff_roles (user_id, role, assigned_by)
SELECT user_id, 'owner', created_by
FROM public.admin_users
ORDER BY created_at, user_id
LIMIT 1
ON CONFLICT (user_id) DO UPDATE SET role = 'owner';

CREATE OR REPLACE FUNCTION public.has_role(role_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.staff_roles sr
      WHERE sr.user_id = auth.uid() AND sr.role = role_name
    ) OR (
      role_name = 'admin' AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
      )
    ) OR (
      role_name = 'user' AND NOT EXISTS (
        SELECT 1 FROM public.staff_roles sr WHERE sr.user_id = auth.uid()
      ) AND NOT EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
      )
    )
  );
$$;
REVOKE ALL ON FUNCTION public.has_role(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_role(TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (SELECT 1 FROM public.staff_roles sr WHERE sr.user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
    )
  );
$$;
REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;

CREATE OR REPLACE FUNCTION public.has_permission(permission_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.staff_roles sr
      WHERE sr.user_id = auth.uid() AND CASE sr.role
        WHEN 'owner' THEN TRUE
        WHEN 'admin' THEN permission_name <> 'staff.owner' OR NOT EXISTS (
          SELECT 1 FROM public.staff_roles owner_role
          WHERE owner_role.role = 'owner'
        )
        WHEN 'moderator' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'content.read', 'content.moderate',
          'reports.read', 'reports.reply'
        ])
        WHEN 'support' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'users.read', 'tickets.read', 'tickets.manage'
        ])
        WHEN 'finance' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'finance.read', 'finance.review'
        ])
        WHEN 'content' THEN permission_name = ANY(ARRAY[
          'dashboard.read', 'content.read', 'content.moderate',
          'announcements.manage'
        ])
        ELSE FALSE
      END
    ) OR (
      permission_name <> 'staff.owner' AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = auth.uid() AND p.role = 'admin' AND p.deleted_at IS NULL
      )
    )
  );
$$;
REVOKE ALL ON FUNCTION public.has_permission(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_permission(TEXT) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.has_role('admin') OR public.has_role('owner');
$$;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

DROP POLICY IF EXISTS staff_roles_read ON public.staff_roles;
CREATE POLICY staff_roles_read ON public.staff_roles
  FOR SELECT USING (public.has_permission('staff.read'));
REVOKE INSERT, UPDATE, DELETE ON public.staff_roles FROM anon, authenticated;

-- Every transaction records the user who initiated it. Service-side operations
-- must provide user_id; clients cannot write transactions directly.
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
UPDATE public.transactions SET created_by = user_id
WHERE created_by IS NULL AND user_id IS NOT NULL;
DROP TRIGGER IF EXISTS set_transaction_actor ON public.transactions;
CREATE OR REPLACE FUNCTION public.set_transaction_actor()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.created_by IS NULL THEN
    NEW.created_by := COALESCE(auth.uid(), NEW.user_id);
  END IF;
  IF NEW.created_by IS NULL THEN
    RAISE EXCEPTION 'Transaction actor is required' USING ERRCODE = '23502';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER set_transaction_actor
  BEFORE INSERT ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.set_transaction_actor();
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check
  CHECK (type IN ('topup', 'p2p', 'redpacket', 'merchant', 'withdraw', 'bill', 'request'));

DROP POLICY IF EXISTS transactions_insert_own ON public.transactions;
DROP POLICY IF EXISTS transactions_own ON public.transactions;
CREATE POLICY transactions_read_own_or_finance ON public.transactions
  FOR SELECT USING (
    user_id = auth.uid() OR public.has_permission('finance.read')
  );
REVOKE INSERT, UPDATE, DELETE ON public.transactions FROM anon, authenticated;

DROP POLICY IF EXISTS wallets_own ON public.wallets;
DROP POLICY IF EXISTS wallets_select_own ON public.wallets;
CREATE POLICY wallets_select_own ON public.wallets
  FOR SELECT USING (user_id = auth.uid());
REVOKE INSERT, UPDATE, DELETE ON public.wallets FROM anon, authenticated;

-- User reports remain private to their reporter; moderation reads and writes go
-- through the service-backed admin-control function.
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS staff_reply TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
DROP POLICY IF EXISTS reports_select_own ON public.reports;
CREATE POLICY reports_select_own_or_staff ON public.reports
  FOR SELECT USING (
    reporter_id = auth.uid() OR public.has_permission('reports.read')
  );
REVOKE UPDATE, DELETE ON public.reports FROM anon, authenticated;

CREATE TABLE IF NOT EXISTS public.tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject TEXT NOT NULL CHECK (length(trim(subject)) BETWEEN 1 AND 160),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'assigned', 'resolved')),
  assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_tickets_status_updated
  ON public.tickets (status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_user_created
  ON public.tickets (user_id, created_at DESC);
DROP POLICY IF EXISTS tickets_user_or_staff_read ON public.tickets;
CREATE POLICY tickets_user_or_staff_read ON public.tickets
  FOR SELECT USING (
    user_id = auth.uid() OR public.has_permission('tickets.read')
  );
DROP POLICY IF EXISTS tickets_user_create ON public.tickets;
CREATE POLICY tickets_user_create ON public.tickets
  FOR INSERT WITH CHECK (user_id = auth.uid());
REVOKE UPDATE, DELETE ON public.tickets FROM anon, authenticated;
GRANT SELECT, INSERT ON public.tickets TO authenticated;

CREATE TABLE IF NOT EXISTS public.ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (length(trim(body)) BETWEEN 1 AND 5000),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket_created
  ON public.ticket_messages (ticket_id, created_at);
DROP POLICY IF EXISTS ticket_messages_read ON public.ticket_messages;
CREATE POLICY ticket_messages_read ON public.ticket_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.tickets t
      WHERE t.id = ticket_id AND t.user_id = auth.uid()
    ) OR public.has_permission('tickets.read')
  );
DROP POLICY IF EXISTS ticket_messages_user_create ON public.ticket_messages;
CREATE POLICY ticket_messages_user_create ON public.ticket_messages
  FOR INSERT WITH CHECK (
    sender_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.tickets t
      WHERE t.id = ticket_id AND t.user_id = auth.uid()
    )
  );
REVOKE UPDATE, DELETE ON public.ticket_messages FROM anon, authenticated;
GRANT SELECT, INSERT ON public.ticket_messages TO authenticated;

CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL CHECK (length(trim(title)) BETWEEN 1 AND 160),
  message TEXT NOT NULL CHECK (length(trim(message)) BETWEEN 1 AND 5000),
  audience TEXT NOT NULL DEFAULT 'all'
    CHECK (audience IN ('all', 'user', 'owner', 'admin', 'moderator', 'support', 'finance', 'content')),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  created_by UUID NOT NULL REFERENCES auth.users(id),
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
CREATE INDEX IF NOT EXISTS idx_announcements_published
  ON public.announcements (published_at DESC) WHERE status = 'published';
DROP POLICY IF EXISTS announcements_public_read ON public.announcements;
CREATE POLICY announcements_public_read ON public.announcements
  FOR SELECT USING (
    (status = 'published' AND auth.uid() IS NOT NULL AND (
      audience = 'all' OR public.has_role(audience)
    )) OR public.has_permission('announcements.manage')
  );
REVOKE INSERT, UPDATE, DELETE ON public.announcements FROM anon, authenticated;

ALTER TABLE public.channel_posts
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE public.oa_posts
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

DROP POLICY IF EXISTS moments_read ON public.moments;
CREATE POLICY moments_read ON public.moments
  FOR SELECT USING (public.can_view_moment(id) AND deleted_at IS NULL);
DROP POLICY IF EXISTS messages_select_member ON public.messages;
CREATE POLICY messages_select_member ON public.messages
  FOR SELECT USING (
    public.is_conversation_member(conversation_id, auth.uid())
    AND deleted_at IS NULL
  );
DROP POLICY IF EXISTS channel_posts_read ON public.channel_posts;
CREATE POLICY channel_posts_read ON public.channel_posts
  FOR SELECT USING (deleted_at IS NULL);
DROP POLICY IF EXISTS oa_posts_read ON public.oa_posts;
CREATE POLICY oa_posts_read ON public.oa_posts
  FOR SELECT USING (deleted_at IS NULL);

CREATE OR REPLACE FUNCTION public.create_support_ticket(
  p_subject TEXT,
  p_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ticket UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF length(trim(p_subject)) NOT BETWEEN 1 AND 160
     OR length(trim(p_message)) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Subject and message are required' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.tickets (user_id, subject)
  VALUES (auth.uid(), trim(p_subject))
  RETURNING id INTO v_ticket;
  INSERT INTO public.ticket_messages (ticket_id, sender_id, body)
  VALUES (v_ticket, auth.uid(), trim(p_message));
  RETURN v_ticket;
END;
$$;
REVOKE ALL ON FUNCTION public.create_support_ticket(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_support_ticket(TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.reply_support_ticket(
  p_ticket UUID,
  p_message TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.tickets
    WHERE id = p_ticket AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Ticket not found' USING ERRCODE = '42501';
  END IF;
  IF length(trim(p_message)) NOT BETWEEN 1 AND 5000 THEN
    RAISE EXCEPTION 'Message cannot be empty' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.ticket_messages (ticket_id, sender_id, body)
  VALUES (p_ticket, auth.uid(), trim(p_message));
  UPDATE public.tickets SET status = 'open', updated_at = NOW()
  WHERE id = p_ticket AND user_id = auth.uid();
END;
$$;
REVOKE ALL ON FUNCTION public.reply_support_ticket(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reply_support_ticket(UUID, TEXT) TO authenticated;

-- Feature flags are public configuration; only service-backed staff actions
-- can change them. The app reads these on startup and after auth changes.
ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS feature_flags_read ON public.feature_flags;
CREATE POLICY feature_flags_read ON public.feature_flags
  FOR SELECT USING (TRUE);
REVOKE INSERT, UPDATE, DELETE ON public.feature_flags FROM anon, authenticated;
INSERT INTO public.feature_flags (key, enabled, description, rollout_percent)
VALUES ('maintenance_mode', FALSE, 'Temporarily restrict app access', 100)
ON CONFLICT (key) DO NOTHING;

DROP POLICY IF EXISTS audit_log_staff_read ON public.audit_log;
CREATE POLICY audit_log_staff_read ON public.audit_log
  FOR SELECT USING (public.has_permission('audit.read'));
REVOKE INSERT, UPDATE, DELETE ON public.audit_log FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_review_transaction(
  p_transaction_id UUID,
  p_approve BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_txn public.transactions;
  v_balance BIGINT;
BEGIN
  IF auth.uid() IS NULL OR NOT public.has_permission('finance.review') THEN
    RAISE EXCEPTION 'Finance permission required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_txn FROM public.transactions
  WHERE id = p_transaction_id FOR UPDATE;
  IF NOT FOUND OR v_txn.status <> 'pending' THEN
    RAISE EXCEPTION 'Pending transaction not found' USING ERRCODE = 'P0002';
  END IF;
  IF v_txn.type NOT IN ('topup', 'bill') OR v_txn.provider_ref IS NULL THEN
    RAISE EXCEPTION 'A verified provider reference is required' USING ERRCODE = '22023';
  END IF;

  IF p_approve THEN
    INSERT INTO public.wallets (user_id) VALUES (v_txn.user_id)
    ON CONFLICT (user_id) DO NOTHING;
    PERFORM 1 FROM public.wallets WHERE user_id = v_txn.user_id FOR UPDATE;
    IF NOT EXISTS (
      SELECT 1 FROM public.wallets
      WHERE user_id = v_txn.user_id AND status = 'active'
    ) THEN
      RAISE EXCEPTION 'Wallet is not active' USING ERRCODE = '42501';
    END IF;

    IF v_txn.type = 'bill' THEN
      SELECT COALESCE(SUM(
        CASE WHEN direction = 'credit' THEN amount_minor ELSE -amount_minor END
      ), 0)::BIGINT INTO v_balance
      FROM public.ledger_entries WHERE account = v_txn.user_id::TEXT;
      IF v_balance < v_txn.amount_minor + COALESCE(v_txn.fee_minor, 0) THEN
        RAISE EXCEPTION 'Insufficient balance' USING ERRCODE = '22003';
      END IF;
      INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
      VALUES
        (v_txn.id, v_txn.user_id::TEXT, 'debit', v_txn.amount_minor + COALESCE(v_txn.fee_minor, 0)),
        (v_txn.id, 'system:bill', 'credit', v_txn.amount_minor + COALESCE(v_txn.fee_minor, 0));
    ELSE
      INSERT INTO public.ledger_entries (txn_id, account, direction, amount_minor)
      VALUES
        (v_txn.id, 'system:topup', 'debit', v_txn.amount_minor),
        (v_txn.id, v_txn.user_id::TEXT, 'credit', v_txn.amount_minor);
    END IF;
    UPDATE public.transactions SET status = 'success', updated_at = NOW()
    WHERE id = v_txn.id;
  ELSE
    UPDATE public.transactions SET status = 'failed', updated_at = NOW()
    WHERE id = v_txn.id;
  END IF;

  INSERT INTO public.audit_log (actor_id, action, target_type, target_id, metadata)
  VALUES (
    auth.uid(),
    CASE WHEN p_approve THEN 'finance.transaction.approved' ELSE 'finance.transaction.rejected' END,
    'transaction', v_txn.id::TEXT,
    jsonb_build_object('type', v_txn.type, 'amount_minor', v_txn.amount_minor)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_review_transaction(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_review_transaction(UUID, BOOLEAN) TO authenticated;
