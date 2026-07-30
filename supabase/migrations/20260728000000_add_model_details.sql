alter table public.mar_symptom_entries
add column if not exists model_details jsonb not null default '{}'::jsonb;
