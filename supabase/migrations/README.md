# Supabase Migrations

This directory contains the SQL migration scripts that define the TaskCards database schema.

## Migration Files

| File | Purpose |
|---|---|
| `0001_init_types.sql` | Creates all custom PostgreSQL enum types |
| `0002_init_tables.sql` | Creates all base tables for the MVP |

## Running Migrations

Migrations are applied in filename order by the Supabase CLI:

```bash
supabase db reset   # drops and recreates the local DB, then applies all migrations
supabase db push    # applies pending migrations to the linked remote project
```

All scripts are **idempotent** — they can be run multiple times without error by using `DO $$ … EXCEPTION WHEN duplicate_object …` blocks for types and `CREATE TABLE IF NOT EXISTS` for tables.

## Enum Types (`0001_init_types.sql`)

| Type | Values | Used By |
|---|---|---|
| `integration_provider` | `github`, `jira`, `linear`, `trello`, `asana` | `integration_accounts.provider`, `tasks_cache.provider` |
| `task_status` | `open`, `in_progress`, `done`, `closed`, `archived` | `tasks_cache.status` |
| `sync_state` | `idle`, `running`, `completed`, `failed` | `sync_runs.state` |
| `pack_type` | `sprint`, `project`, `custom`, `backlog` | `packs.type` |
| `relationship_type` | `blocks`, `blocked_by`, `relates_to`, `duplicates`, `parent_of`, `child_of` | `task_relationships.relationship` |

## Tables (`0002_init_tables.sql`)

### `profiles`
One row per authenticated user. The primary key references `auth.users(id)` so that Supabase Auth acts as the source of truth for identity. Display name and avatar are stored here for quick lookups without calling the auth API.

### `integration_accounts`
Represents a connection between a user and a third-party task provider (e.g. GitHub, Jira). A composite unique constraint on `(user_id, provider, provider_account_id)` prevents duplicate connections. The `metadata` JSONB column stores provider-specific settings.

### `integration_secrets`
Stores OAuth tokens for each integration account. Access and refresh tokens live here, along with an expiry timestamp. **Note:** Supabase encrypts data at rest, but consider using Vault for additional encryption if requirements dictate.

### `integration_criteria`
Defines the filters or queries used when syncing tasks from a provider (e.g. specific repos, JQL filters, label selectors). Criteria can be toggled on/off via `is_active`.

### `tasks_cache`
A denormalised copy of tasks pulled from external providers. Each row is uniquely identified by `(integration_account_id, provider_task_id)` so upserts during sync are straightforward. Extra fields like `labels` (JSONB array) and `metadata` (JSONB object) capture provider-specific data without requiring schema changes.

### `packs`
User-created groupings of tasks — think of them as card decks. Each pack has a type (`sprint`, `project`, `custom`, `backlog`) and optional metadata.

### `pack_items`
An ordered junction table linking packs to cached tasks. The `position` column enables drag-and-drop reordering. A unique constraint on `(pack_id, task_id)` prevents adding the same task to a pack twice.

### `task_relationships`
Directed edges between cached tasks (e.g. "blocks", "parent_of"). The unique constraint on `(source_task_id, target_task_id, relationship)` prevents duplicate relationships.

### `sync_runs`
An audit log recording every sync execution. Tracks state transitions (`idle` → `running` → `completed` / `failed`), the number of tasks synced, and any error messages. Useful for debugging and displaying sync history to the user.

## Design Decisions

- **UUID primary keys** — avoids sequential ID enumeration and simplifies cross-system references.
- **`ON DELETE CASCADE`** — child rows are automatically cleaned up when a parent is removed, keeping referential integrity simple at the MVP stage.
- **`timestamptz`** — all timestamps are timezone-aware to avoid ambiguity across time zones.
- **JSONB columns** — `metadata`, `labels`, and `criteria` use JSONB so provider-specific data can be stored without schema migrations.
- **`created_at` / `updated_at` defaults** — every table gets these columns with `DEFAULT now()` so application code doesn't need to set them explicitly. (An `updated_at` trigger can be added in a later migration.)
