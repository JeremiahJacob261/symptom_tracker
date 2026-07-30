create table if not exists public.mar_ai_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  insight_type text not null,
  range_key text not null,
  summary text not null,
  patterns jsonb not null default '[]'::jsonb,
  education jsonb not null default '[]'::jsonb,
  care_guidance jsonb not null default '[]'::jsonb,
  red_flags jsonb not null default '[]'::jsonb,
  trend text not null default 'unknown',
  safety_status text not null default 'safe',
  model text not null,
  input_stats jsonb not null default '{}'::jsonb,
  raw_response jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.mar_ai_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  report_type text not null,
  range_key text not null,
  patient_summary text not null,
  clinician_summary text,
  suggested_questions jsonb not null default '[]'::jsonb,
  model text not null,
  input_stats jsonb not null default '{}'::jsonb,
  safety_status text not null default 'safe',
  created_at timestamptz not null default now()
);

create table if not exists public.mar_ai_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  insight_id uuid references public.mar_ai_insights(id) on delete cascade,
  report_id uuid references public.mar_ai_reports(id) on delete cascade,
  rating text not null,
  notes text,
  created_at timestamptz not null default now(),
  constraint mar_ai_feedback_target_check
    check (insight_id is not null or report_id is not null)
);

alter table public.mar_ai_insights enable row level security;
alter table public.mar_ai_reports enable row level security;
alter table public.mar_ai_feedback enable row level security;

grant select, insert, update, delete on public.mar_ai_insights to authenticated;
grant select, insert, update, delete on public.mar_ai_reports to authenticated;
grant select, insert, update, delete on public.mar_ai_feedback to authenticated;

create policy "mar_ai_insights_select_own"
on public.mar_ai_insights for select to authenticated
using (user_id = auth.uid());

create policy "mar_ai_insights_insert_own"
on public.mar_ai_insights for insert to authenticated
with check (user_id = auth.uid());

create policy "mar_ai_insights_update_own"
on public.mar_ai_insights for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "mar_ai_insights_delete_own"
on public.mar_ai_insights for delete to authenticated
using (user_id = auth.uid());

create policy "mar_ai_reports_select_own"
on public.mar_ai_reports for select to authenticated
using (user_id = auth.uid());

create policy "mar_ai_reports_insert_own"
on public.mar_ai_reports for insert to authenticated
with check (user_id = auth.uid());

create policy "mar_ai_reports_update_own"
on public.mar_ai_reports for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "mar_ai_reports_delete_own"
on public.mar_ai_reports for delete to authenticated
using (user_id = auth.uid());

create policy "mar_ai_feedback_select_own"
on public.mar_ai_feedback for select to authenticated
using (user_id = auth.uid());

create policy "mar_ai_feedback_insert_own"
on public.mar_ai_feedback for insert to authenticated
with check (user_id = auth.uid());

create policy "mar_ai_feedback_update_own"
on public.mar_ai_feedback for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "mar_ai_feedback_delete_own"
on public.mar_ai_feedback for delete to authenticated
using (user_id = auth.uid());
