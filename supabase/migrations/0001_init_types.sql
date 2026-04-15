-- 0001_init_types.sql
-- Creates custom enum types used across the TaskCards schema.
-- Idempotent: uses DO blocks to skip creation when types already exist.

DO $$ BEGIN
  CREATE TYPE integration_provider AS ENUM (
    'github',
    'jira',
    'linear',
    'trello',
    'asana'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE task_status AS ENUM (
    'open',
    'in_progress',
    'done',
    'closed',
    'archived'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE sync_state AS ENUM (
    'idle',
    'running',
    'completed',
    'failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE pack_type AS ENUM (
    'sprint',
    'project',
    'custom',
    'backlog'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE relationship_type AS ENUM (
    'blocks',
    'blocked_by',
    'relates_to',
    'duplicates',
    'parent_of',
    'child_of'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
