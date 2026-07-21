-- Business Manager Dashboard — Supabase schema
-- Run this once in: Supabase dashboard -> SQL Editor -> New query -> paste -> Run
--
-- Every table has a user_id column that defaults to the signed-in user
-- (auth.uid()) and Row Level Security (RLS) policies that only let a user
-- see/change their OWN rows. This is what keeps each person's data private
-- when everyone shares the same database.

create table if not exists public.projects (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  logo_url text,
  created_at timestamptz not null default now()
);

-- Run this if the "projects" table already existed before the logo feature:
alter table public.projects add column if not exists logo_url text;

create table if not exists public.cost_items (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  name text not null,
  unique (project_id, name)
);

create table if not exists public.cost_history (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  item_id bigint not null references public.cost_items(id) on delete cascade,
  month text not null,
  cost numeric not null,
  unique (project_id, item_id, month)
);

create table if not exists public.cost_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  item_id bigint not null references public.cost_items(id) on delete cascade,
  date text not null,
  quantity numeric not null,
  unique (project_id, item_id, date)
);

create table if not exists public.daily_records (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  date text not null,
  sales_amount numeric not null default 0,
  unique (project_id, date)
);

create table if not exists public.daily_expenses (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  date text not null,
  category text not null,
  amount numeric not null,
  notes text not null default ''
);

create table if not exists public.inventory_items (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  name text not null,
  category text not null default '',
  unit text not null default '',
  purchase_quantity numeric not null,
  purchase_price numeric not null,
  used_quantity numeric not null default 0
);

create table if not exists public.inventory_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  item_id bigint not null references public.inventory_items(id) on delete cascade,
  date text not null,
  quantity numeric not null
);

create table if not exists public.fixed_expenses (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  name text not null,
  monthly_amount numeric not null,
  start_month text not null,
  notes text not null default ''
);

-- Atomically records inventory usage AND increases the item's used_quantity
-- (mirrors what a single local transaction used to do).
create or replace function public.add_inventory_usage(
  p_item_id bigint, p_project_id bigint, p_date text, p_quantity numeric
) returns void
language plpgsql
security invoker
as $$
begin
  insert into public.inventory_usage (project_id, item_id, date, quantity)
  values (p_project_id, p_item_id, p_date, p_quantity);

  update public.inventory_items
  set used_quantity = used_quantity + p_quantity
  where id = p_item_id;
end;
$$;

-- ---------- Row Level Security: everyone can only touch their own rows ----------

alter table public.projects enable row level security;
alter table public.cost_items enable row level security;
alter table public.cost_history enable row level security;
alter table public.cost_usage enable row level security;
alter table public.daily_records enable row level security;
alter table public.daily_expenses enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_usage enable row level security;
alter table public.fixed_expenses enable row level security;

create policy "own rows" on public.projects for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.cost_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.cost_history for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.cost_usage for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.daily_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.daily_expenses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.inventory_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.inventory_usage for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.fixed_expenses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- Storage bucket for per-project logos (used in-app and in printed reports) ----------

insert into storage.buckets (id, name, public)
values ('project-logos', 'project-logos', true)
on conflict (id) do nothing;

-- Anyone can read a logo (needed to display it and to embed it in printed PDFs).
create policy if not exists "project logos are publicly readable"
on storage.objects for select
using (bucket_id = 'project-logos');

-- A user can only upload/replace/delete logos stored under their own uid folder,
-- e.g. project-logos/{user_id}/{project_id}.png
create policy if not exists "users manage their own project logos"
on storage.objects for all
using (bucket_id = 'project-logos' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'project-logos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Helpful indexes for the lookups the app does most often.
create index if not exists idx_daily_records_proj_date on public.daily_records (project_id, date);
create index if not exists idx_cost_usage_proj_date on public.cost_usage (project_id, date);
create index if not exists idx_cost_history_proj_item_month on public.cost_history (project_id, item_id, month);
create index if not exists idx_daily_expenses_proj_date on public.daily_expenses (project_id, date);
create index if not exists idx_inventory_usage_proj_date on public.inventory_usage (project_id, date);
