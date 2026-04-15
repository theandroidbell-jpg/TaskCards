-- 0002_init_tables.sql
-- Creates all base tables for the TaskCards MVP.
-- Idempotent: uses CREATE TABLE IF NOT EXISTS.
-- Depends on enum types created in 0001_init_types.sql.

-- ============================================================
-- profiles – one row per authenticated user
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name text,
  avatar_url  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- integration_accounts – third-party provider connections
-- ============================================================
CREATE TABLE IF NOT EXISTS integration_accounts (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  provider            integration_provider NOT NULL,
  provider_account_id text NOT NULL,
  provider_username   text,
  metadata            jsonb NOT NULL DEFAULT '{}',
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider, provider_account_id)
);

-- ============================================================
-- integration_secrets – OAuth / API tokens (encrypted at rest)
-- ============================================================
CREATE TABLE IF NOT EXISTS integration_secrets (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_account_id  uuid NOT NULL REFERENCES integration_accounts (id) ON DELETE CASCADE,
  access_token            text NOT NULL,
  refresh_token           text,
  token_expires_at        timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- integration_criteria – filters / queries used during sync
-- ============================================================
CREATE TABLE IF NOT EXISTS integration_criteria (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_account_id  uuid NOT NULL REFERENCES integration_accounts (id) ON DELETE CASCADE,
  label                   text,
  criteria                jsonb NOT NULL DEFAULT '{}',
  is_active               boolean NOT NULL DEFAULT true,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- tasks_cache – denormalized copy of tasks pulled from providers
-- ============================================================
CREATE TABLE IF NOT EXISTS tasks_cache (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_account_id  uuid NOT NULL REFERENCES integration_accounts (id) ON DELETE CASCADE,
  provider                integration_provider NOT NULL,
  provider_task_id        text NOT NULL,
  title                   text NOT NULL,
  description             text,
  status                  task_status NOT NULL DEFAULT 'open',
  priority                integer,
  labels                  jsonb NOT NULL DEFAULT '[]',
  metadata                jsonb NOT NULL DEFAULT '{}',
  due_at                  timestamptz,
  completed_at            timestamptz,
  remote_created_at       timestamptz,
  remote_updated_at       timestamptz,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  UNIQUE (integration_account_id, provider_task_id)
);

-- ============================================================
-- packs – user-created groupings of tasks (card decks)
-- ============================================================
CREATE TABLE IF NOT EXISTS packs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES profiles (id) ON DELETE CASCADE,
  title       text NOT NULL,
  description text,
  type        pack_type NOT NULL DEFAULT 'custom',
  metadata    jsonb NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- pack_items – ordered junction between packs and cached tasks
-- ============================================================
CREATE TABLE IF NOT EXISTS pack_items (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id    uuid NOT NULL REFERENCES packs (id) ON DELETE CASCADE,
  task_id    uuid NOT NULL REFERENCES tasks_cache (id) ON DELETE CASCADE,
  position   integer NOT NULL DEFAULT 0,
  notes      text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pack_id, task_id)
);

-- ============================================================
-- task_relationships – directed edges between cached tasks
-- ============================================================
CREATE TABLE IF NOT EXISTS task_relationships (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_task_id  uuid NOT NULL REFERENCES tasks_cache (id) ON DELETE CASCADE,
  target_task_id  uuid NOT NULL REFERENCES tasks_cache (id) ON DELETE CASCADE,
  relationship    relationship_type NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source_task_id, target_task_id, relationship)
);

-- ============================================================
-- sync_runs – audit log for every integration sync execution
-- ============================================================
CREATE TABLE IF NOT EXISTS sync_runs (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_account_id  uuid NOT NULL REFERENCES integration_accounts (id) ON DELETE CASCADE,
  state                   sync_state NOT NULL DEFAULT 'idle',
  started_at              timestamptz,
  completed_at            timestamptz,
  tasks_synced            integer NOT NULL DEFAULT 0,
  error_message           text,
  metadata                jsonb NOT NULL DEFAULT '{}',
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
