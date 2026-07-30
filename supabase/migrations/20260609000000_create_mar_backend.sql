create extension if not exists pgcrypto;

create table if not exists public.mar_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  timezone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.mar_symptom_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  pain_level int check (pain_level >= 0 and pain_level <= 10),
  body_area text,
  mood text,
  notes text,
  photo_path text,
  occurred_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, client_id)
);

create table if not exists public.mar_medications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  name text,
  dosage text,
  frequency text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, client_id)
);

create table if not exists public.mar_appointments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id text not null,
  title text,
  doctor text,
  appointment_date date,
  appointment_time time,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, client_id)
);

alter table public.mar_profiles enable row level security;
alter table public.mar_symptom_entries enable row level security;
alter table public.mar_medications enable row level security;
alter table public.mar_appointments enable row level security;

grant select, insert, update, delete on public.mar_profiles to authenticated;
grant select, insert, update, delete on public.mar_symptom_entries to authenticated;
grant select, insert, update, delete on public.mar_medications to authenticated;
grant select, insert, update, delete on public.mar_appointments to authenticated;

create policy "mar_profiles_select_own"
on public.mar_profiles for select to authenticated
using (id = auth.uid());

create policy "mar_profiles_insert_own"
on public.mar_profiles for insert to authenticated
with check (id = auth.uid());

create policy "mar_profiles_update_own"
on public.mar_profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "mar_profiles_delete_own"
on public.mar_profiles for delete to authenticated
using (id = auth.uid());

create policy "mar_symptom_entries_select_own"
on public.mar_symptom_entries for select to authenticated
using (user_id = auth.uid());

create policy "mar_symptom_entries_insert_own"
on public.mar_symptom_entries for insert to authenticated
with check (user_id = auth.uid());

create policy "mar_symptom_entries_update_own"
on public.mar_symptom_entries for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "mar_symptom_entries_delete_own"
on public.mar_symptom_entries for delete to authenticated
using (user_id = auth.uid());

create policy "mar_medications_select_own"
on public.mar_medications for select to authenticated
using (user_id = auth.uid());

create policy "mar_medications_insert_own"
on public.mar_medications for insert to authenticated
with check (user_id = auth.uid());

create policy "mar_medications_update_own"
on public.mar_medications for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "mar_medications_delete_own"
on public.mar_medications for delete to authenticated
using (user_id = auth.uid());

create policy "mar_appointments_select_own"
on public.mar_appointments for select to authenticated
using (user_id = auth.uid());

create policy "mar_appointments_insert_own"
on public.mar_appointments for insert to authenticated
with check (user_id = auth.uid());

create policy "mar_appointments_update_own"
on public.mar_appointments for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "mar_appointments_delete_own"
on public.mar_appointments for delete to authenticated
using (user_id = auth.uid());

insert into storage.buckets (id, name, public)
values ('mar_symptom_photos', 'mar_symptom_photos', false)
on conflict (id) do nothing;

create policy "mar_symptom_photos_select_own"
on storage.objects for select to authenticated
using (
  bucket_id = 'mar_symptom_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

create policy "mar_symptom_photos_insert_own"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'mar_symptom_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

create policy "mar_symptom_photos_update_own"
on storage.objects for update to authenticated
using (
  bucket_id = 'mar_symptom_photos'
  and split_part(name, '/', 1) = auth.uid()::text
)
with check (
  bucket_id = 'mar_symptom_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);

create policy "mar_symptom_photos_delete_own"
on storage.objects for delete to authenticated
using (
  bucket_id = 'mar_symptom_photos'
  and split_part(name, '/', 1) = auth.uid()::text
);
