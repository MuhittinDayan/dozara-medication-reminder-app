-- Supabase schema for the medication reminder app.
-- Run this in the Supabase SQL editor after creating the project.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color_value integer not null default 4278221211,
  avatar_url text not null default '',
  is_caregiver_mode boolean not null default false,
  relation text not null default 'Ben',
  receives_dose_notifications boolean not null default true,
  can_manage_medicines boolean not null default true,
  is_emergency_contact boolean not null default false,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.medicines (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id text references public.profiles(id) on delete set null,
  name text not null,
  daily_frequency integer not null default 1,
  total_days integer not null default 1,
  first_dose_time text not null default '09:00',
  start_date timestamptz not null,
  stock_count integer,
  stock_warning_threshold integer not null default 5,
  is_active boolean not null default true,
  color_value integer not null default 4281231666,
  form text not null default 'pill',
  note text,
  with_food boolean not null default false,
  dosage text,
  schedule_type text not null default 'daily',
  selected_weekdays integer[],
  interval_days integer,
  reminder_times text[],
  low_stock_threshold integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.dose_logs (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  profile_id text references public.profiles(id) on delete set null,
  medicine_id text not null references public.medicines(id) on delete cascade,
  scheduled_time timestamptz not null,
  status text not null default 'pending',
  action_time timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.stock_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  medicine_id text not null references public.medicines(id) on delete cascade,
  delta integer not null,
  resulting_stock integer not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active_profile_id text,
  theme_mode text not null default 'system',
  notification_vibration boolean not null default true,
  voice_reminder boolean not null default true,
  family_notification boolean not null default false,
  onboarding_completed boolean not null default false,
  onboarding_conditions text[] not null default '{}',
  onboarding_birth_date text not null default '',
  disabled_alarm_keys text[] not null default '{}',
  gemini_managed_alarm_keys text[] not null default '{}',
  updated_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  platform text not null,
  push_token text,
  app_version text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, device_id)
);

create index if not exists medicines_user_profile_idx
  on public.medicines (user_id, profile_id)
  where deleted_at is null;

create index if not exists dose_logs_user_time_idx
  on public.dose_logs (user_id, scheduled_time)
  where deleted_at is null;

create index if not exists dose_logs_medicine_time_idx
  on public.dose_logs (medicine_id, scheduled_time)
  where deleted_at is null;

alter table public.profiles enable row level security;
alter table public.medicines enable row level security;
alter table public.dose_logs enable row level security;
alter table public.stock_events enable row level security;
alter table public.user_settings enable row level security;
alter table public.devices enable row level security;

create policy "Users manage own profiles"
  on public.profiles for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own medicines"
  on public.medicines for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own dose logs"
  on public.dose_logs for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own stock events"
  on public.stock_events for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own settings"
  on public.user_settings for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own devices"
  on public.devices for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
