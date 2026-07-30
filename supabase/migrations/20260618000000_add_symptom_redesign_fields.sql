alter table public.mar_symptom_entries
add column if not exists symptoms jsonb not null default '[]'::jsonb,
add column if not exists custom_symptoms text,
add column if not exists temperature_celsius numeric;
