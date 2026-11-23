-- Timer v0.9.0 — sync schema + RLS.
--
-- Mirrors the local drift tables (lib/core/services/database/tables.dart)
-- for the two synced tables, `activities` and `sessions`. Local SQLite
-- stays the source of truth; these tables exist only so each signed-in
-- user's own rows can be pushed/pulled across their devices.
--
-- Idempotent: safe to re-run (see docs/superpowers/sync/supabase-setup.md).
-- Apply via the Supabase SQL editor or `supabase db push --file sync.sql`.

create table if not exists public.activities (
  user_id uuid not null default auth.uid() references auth.users (id),
  uid text not null,
  name text not null,
  color bigint,
  hourly_rate double precision,
  currency_label text,
  archived boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (user_id, uid)
);

create table if not exists public.sessions (
  user_id uuid not null default auth.uid() references auth.users (id),
  uid text not null,
  -- The activity's `uid` (not its local autoincrement id, which differs
  -- per device) — the cross-device foreign key.
  activity_uid text not null,
  date timestamptz not null,
  start_time timestamptz not null,
  end_time timestamptz,
  duration_seconds bigint not null default 0,
  note text,
  last_seen_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (user_id, uid)
);

alter table public.activities enable row level security;
alter table public.sessions enable row level security;

drop policy if exists "activities_select_own" on public.activities;
create policy "activities_select_own" on public.activities
  for select using (user_id = auth.uid());

drop policy if exists "activities_insert_own" on public.activities;
create policy "activities_insert_own" on public.activities
  for insert with check (user_id = auth.uid());

drop policy if exists "activities_update_own" on public.activities;
create policy "activities_update_own" on public.activities
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "activities_delete_own" on public.activities;
create policy "activities_delete_own" on public.activities
  for delete using (user_id = auth.uid());

drop policy if exists "sessions_select_own" on public.sessions;
create policy "sessions_select_own" on public.sessions
  for select using (user_id = auth.uid());

drop policy if exists "sessions_insert_own" on public.sessions;
create policy "sessions_insert_own" on public.sessions
  for insert with check (user_id = auth.uid());

drop policy if exists "sessions_update_own" on public.sessions;
create policy "sessions_update_own" on public.sessions
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "sessions_delete_own" on public.sessions;
create policy "sessions_delete_own" on public.sessions
  for delete using (user_id = auth.uid());
