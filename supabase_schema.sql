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
  archived boolean not null default false,
  unique (project_id, name)
);

-- Run this if "cost_items" already existed: lets an item be archived
-- (hidden from new-entry pickers) instead of hard-deleted, so its
-- historical monthly costs/usage — and therefore past reports — are
-- never wiped out just because you stopped using the item.
alter table public.cost_items add column if not exists archived boolean not null default false;
-- NOTE: linked_inventory_item_id / consumption_per_unit are added further
-- down, AFTER the inventory_items table exists (a foreign key can't point
-- to a table that isn't created yet).

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
  item_id bigint references public.cost_items(id) on delete set null,
  date text not null,
  quantity numeric not null,
  unit_cost numeric,
  item_name_snapshot text,
  unique (project_id, item_id, date)
);

-- Run this if "cost_usage" already existed: for products linked to
-- inventory, this locks in the derived per-unit cost at the moment of the
-- sale, so a later inventory price change never rewrites a past day.
alter table public.cost_usage add column if not exists unit_cost numeric;

-- Run this if "cost_usage" already existed: lets a cost item be
-- permanently deleted later without breaking old sale rows — item_id can
-- become null, and item_name_snapshot preserves the item's name for
-- display even after it's gone (see permanently_delete_cost_item below).
alter table public.cost_usage add column if not exists item_name_snapshot text;
alter table public.cost_usage alter column item_id drop not null;
alter table public.cost_usage drop constraint if exists cost_usage_item_id_fkey;
alter table public.cost_usage add constraint cost_usage_item_id_fkey
  foreign key (item_id) references public.cost_items(id) on delete set null;

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
  used_quantity numeric not null default 0,
  archived boolean not null default false,
  unit_type text not null default 'piece',
  units_per_container numeric
);

-- Run this if "inventory_items" already existed: same archiving idea as
-- cost_items above, applied to inventory items.
alter table public.inventory_items add column if not exists archived boolean not null default false;
alter table public.inventory_items add column if not exists unit_type text not null default 'piece';
alter table public.inventory_items add column if not exists units_per_container numeric;

-- Now that inventory_items exists, add the optional link from a cost item
-- (a product you sell) to the inventory item it's made of, plus how much
-- inventory (in pieces) each unit sold consumes. Selling it then
-- auto-deducts stock, and its price is derived from the inventory price.
alter table public.cost_items add column if not exists linked_inventory_item_id bigint references public.inventory_items(id) on delete set null;
alter table public.cost_items add column if not exists consumption_per_unit numeric;

create table if not exists public.inventory_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  item_id bigint references public.inventory_items(id) on delete set null,
  date text not null,
  quantity numeric not null,
  unit_cost numeric,
  item_name_snapshot text,
  -- Set only for usage rows generated automatically from a linked cost-item
  -- sale (see upsert_linked_cost_usage below). Null for manual entries.
  source_cost_usage_id bigint references public.cost_usage(id) on delete set null
);

-- Run this if "inventory_usage" already existed before this fix: locks in
-- the item's unit cost at the moment usage is recorded, so a later price
-- change never rewrites the cost of days you already logged.
alter table public.inventory_usage add column if not exists unit_cost numeric;
alter table public.inventory_usage add column if not exists source_cost_usage_id bigint references public.cost_usage(id) on delete set null;
create unique index if not exists idx_inventory_usage_source_cost_usage
  on public.inventory_usage (source_cost_usage_id)
  where source_cost_usage_id is not null;

-- Run this if "inventory_usage" already existed: lets an inventory item be
-- permanently deleted later without breaking old usage rows — item_id can
-- become null, and item_name_snapshot preserves the item's name for
-- display even after it's gone (see permanently_delete_inventory_item below).
alter table public.inventory_usage add column if not exists item_name_snapshot text;
alter table public.inventory_usage alter column item_id drop not null;
alter table public.inventory_usage drop constraint if exists inventory_usage_item_id_fkey;
alter table public.inventory_usage add constraint inventory_usage_item_id_fkey
  foreign key (item_id) references public.inventory_items(id) on delete set null;

create table if not exists public.fixed_expenses (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  project_id bigint not null references public.projects(id) on delete cascade,
  name text not null,
  monthly_amount numeric not null,
  start_month text not null,
  end_month text,
  notes text not null default ''
);

-- Run this if "fixed_expenses" already existed: lets an expense be "ended"
-- (stops applying after end_month) instead of deleted, so past months that
-- already counted it stay correct forever.
alter table public.fixed_expenses add column if not exists end_month text;

-- Atomically records inventory usage AND increases the item's used_quantity
-- (mirrors what a single local transaction used to do). The item's unit
-- cost (purchase_price / purchase_quantity) is snapshotted into unit_cost
-- at the moment of recording, so editing the item's price later never
-- changes the cost of usage you already logged.
create or replace function public.add_inventory_usage(
  p_item_id bigint, p_project_id bigint, p_date text, p_quantity numeric
) returns void
language plpgsql
security invoker
as $$
declare
  v_price numeric;
  v_qty numeric;
  v_unit_cost numeric;
begin
  select purchase_price, purchase_quantity into v_price, v_qty
  from public.inventory_items where id = p_item_id;

  v_unit_cost := case when v_qty is null or v_qty <= 0 then 0 else v_price / v_qty end;

  insert into public.inventory_usage (project_id, item_id, date, quantity, unit_cost)
  values (p_project_id, p_item_id, p_date, p_quantity, v_unit_cost);

  update public.inventory_items
  set used_quantity = used_quantity + p_quantity
  where id = p_item_id;
end;
$$;

-- Deletes all inventory usage recorded for one day AND gives the quantity
-- back to each item's remaining stock (used_quantity), atomically. Used by
-- "delete day" so removing a day's records doesn't leave inventory
-- consumption/stock permanently wrong.
create or replace function public.delete_inventory_usage_for_date(
  p_project_id bigint, p_date text
) returns void
language plpgsql
security invoker
as $$
begin
  update public.inventory_items ii
  set used_quantity = used_quantity - sub.total_qty
  from (
    select item_id, sum(quantity) as total_qty
    from public.inventory_usage
    where project_id = p_project_id and date = p_date
    group by item_id
  ) sub
  where ii.id = sub.item_id;

  delete from public.inventory_usage
  where project_id = p_project_id and date = p_date;
end;
$$;

-- Adds a new purchase batch to an inventory item atomically: increases the
-- total purchased quantity and total purchase value by the given amounts
-- (never overwrites them), so past recorded usage keeps its own locked-in
-- price and only NEW usage prices at the resulting blended average.
create or replace function public.restock_inventory_item(
  p_item_id bigint, p_added_quantity numeric, p_added_price numeric
) returns void
language plpgsql
security invoker
as $$
begin
  update public.inventory_items
  set purchase_quantity = purchase_quantity + p_added_quantity,
      purchase_price = purchase_price + p_added_price
  where id = p_item_id;
end;
$$;

-- Upserts a cost-item sale for one day. If that cost item is linked to an
-- inventory item, this ALSO derives the sale's unit cost from the
-- inventory item's CURRENT price (locking it into cost_usage.unit_cost so
-- a later price change never rewrites this day), and keeps a paired
-- inventory_usage row in sync — inserting it, or adjusting it by the
-- DELTA if this day's quantity is being edited (never double-counted).
create or replace function public.upsert_linked_cost_usage(
  p_project_id bigint, p_item_id bigint, p_date text, p_quantity numeric
) returns void
language plpgsql
security invoker
as $$
declare
  v_inv_item_id bigint;      -- currently-linked inventory item (may be null)
  v_consumption numeric;
  v_inv_price numeric;
  v_inv_qty numeric;
  v_inv_unit_cost numeric := null;
  v_unit_cost numeric := null;
  v_new_inv_qty numeric := 0;
  v_cost_usage_id bigint;
  v_old_inv_item_id bigint;  -- item_id on the existing derived row, if any
  v_old_inv_qty numeric;
begin
  select linked_inventory_item_id, consumption_per_unit
    into v_inv_item_id, v_consumption
  from public.cost_items where id = p_item_id;

  if v_inv_item_id is not null then
    select purchase_price, purchase_quantity into v_inv_price, v_inv_qty
    from public.inventory_items where id = v_inv_item_id;
    v_inv_unit_cost := case when v_inv_qty is null or v_inv_qty <= 0
      then 0 else v_inv_price / v_inv_qty end;
    v_unit_cost := v_inv_unit_cost * coalesce(v_consumption, 1);
    v_new_inv_qty := p_quantity * coalesce(v_consumption, 1);
  end if;

  insert into public.cost_usage (project_id, item_id, date, quantity, unit_cost)
  values (p_project_id, p_item_id, p_date, p_quantity, v_unit_cost)
  on conflict (project_id, item_id, date)
  do update set quantity = excluded.quantity, unit_cost = excluded.unit_cost
  returning id into v_cost_usage_id;

  -- Find any previously-derived inventory usage row tied to this sale (uses
  -- FOUND rather than "quantity = 0", so a prior row that happens to have
  -- quantity 0 is still correctly treated as "exists").
  select item_id, quantity into v_old_inv_item_id, v_old_inv_qty
  from public.inventory_usage where source_cost_usage_id = v_cost_usage_id;
  if not found then
    v_old_inv_item_id := null;
    v_old_inv_qty := 0;
  end if;

  -- If the item is no longer linked (or is now linked to a DIFFERENT
  -- inventory item than before), reverse and remove the stale derived row
  -- first so stock is never left out of sync.
  if v_old_inv_item_id is not null and
     (v_inv_item_id is null or v_old_inv_item_id <> v_inv_item_id) then
    update public.inventory_items
    set used_quantity = used_quantity - v_old_inv_qty
    where id = v_old_inv_item_id;
    delete from public.inventory_usage where source_cost_usage_id = v_cost_usage_id;
    v_old_inv_item_id := null;
    v_old_inv_qty := 0;
  end if;

  if v_inv_item_id is not null then
    if v_old_inv_item_id is null then
      insert into public.inventory_usage
        (project_id, item_id, date, quantity, unit_cost, source_cost_usage_id)
      values
        (p_project_id, v_inv_item_id, p_date, v_new_inv_qty, v_inv_unit_cost, v_cost_usage_id);
    else
      update public.inventory_usage
      set quantity = v_new_inv_qty, unit_cost = v_inv_unit_cost, date = p_date
      where source_cost_usage_id = v_cost_usage_id;
    end if;

    update public.inventory_items
    set used_quantity = used_quantity + (v_new_inv_qty - v_old_inv_qty)
    where id = v_inv_item_id;
  end if;
end;
$$;

-- Deletes one cost-item sale row and, if it had a linked/derived inventory
-- usage row, reverses that stock deduction and removes it too.
create or replace function public.delete_linked_cost_usage(
  p_cost_usage_id bigint
) returns void
language plpgsql
security invoker
as $$
declare
  v_inv_item_id bigint;
  v_qty numeric;
begin
  select item_id, quantity into v_inv_item_id, v_qty
  from public.inventory_usage where source_cost_usage_id = p_cost_usage_id;

  if v_inv_item_id is not null then
    update public.inventory_items
    set used_quantity = used_quantity - v_qty
    where id = v_inv_item_id;

    delete from public.inventory_usage where source_cost_usage_id = p_cost_usage_id;
  end if;

  delete from public.cost_usage where id = p_cost_usage_id;
end;
$$;

-- Permanently deletes a "cost of products used" item WITHOUT touching any
-- past report: every sale row tied to it first gets its per-unit cost
-- frozen (mirroring the exact same "exact month, else most recent prior
-- month" rule the app already uses) and the item's name snapshotted, so
-- the row no longer needs the item to exist. Only then is the item
-- actually deleted (item_id on those rows becomes null via ON DELETE SET
-- NULL — the row itself is never touched).
create or replace function public.permanently_delete_cost_item(p_item_id bigint)
returns void
language plpgsql
security invoker
as $$
declare
  v_name text;
begin
  select name into v_name from public.cost_items where id = p_item_id;
  if v_name is null then
    return;
  end if;

  update public.cost_usage cu
  set unit_cost = coalesce(
        cu.unit_cost,
        (
          select ch.cost from public.cost_history ch
          where ch.item_id = p_item_id
            and ch.month <= substring(cu.date, 1, 7)
          order by (ch.month = substring(cu.date, 1, 7)) desc, ch.month desc
          limit 1
        ),
        0
      ),
      item_name_snapshot = v_name
  where cu.item_id = p_item_id;

  delete from public.cost_items where id = p_item_id;
end;
$$;

-- Same idea for an inventory item: freezes each usage row's unit cost
-- (using the item's current price, same fallback the app already uses for
-- old rows) and its name, then deletes the item. Note: if this item is
-- linked to a "cost of products used" item, that link is cleared
-- automatically (linked_inventory_item_id has ON DELETE SET NULL) — the
-- linked product itself is NOT deleted, just unlinked.
create or replace function public.permanently_delete_inventory_item(p_item_id bigint)
returns void
language plpgsql
security invoker
as $$
declare
  v_name text;
  v_price numeric;
  v_qty numeric;
  v_unit_cost numeric;
begin
  select name, purchase_price, purchase_quantity
    into v_name, v_price, v_qty
  from public.inventory_items where id = p_item_id;
  if v_name is null then
    return;
  end if;
  v_unit_cost := case when v_qty is null or v_qty <= 0 then 0 else v_price / v_qty end;

  update public.inventory_usage iu
  set unit_cost = coalesce(iu.unit_cost, v_unit_cost),
      item_name_snapshot = v_name
  where iu.item_id = p_item_id;

  delete from public.inventory_items where id = p_item_id;
end;
$$;

alter table public.projects enable row level security;
alter table public.cost_items enable row level security;
alter table public.cost_history enable row level security;
alter table public.cost_usage enable row level security;
alter table public.daily_records enable row level security;
alter table public.daily_expenses enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_usage enable row level security;
alter table public.fixed_expenses enable row level security;

drop policy if exists "own rows" on public.projects;
create policy "own rows" on public.projects for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.cost_items;
create policy "own rows" on public.cost_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.cost_history;
create policy "own rows" on public.cost_history for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.cost_usage;
create policy "own rows" on public.cost_usage for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.daily_records;
create policy "own rows" on public.daily_records for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.daily_expenses;
create policy "own rows" on public.daily_expenses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.inventory_items;
create policy "own rows" on public.inventory_items for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.inventory_usage;
create policy "own rows" on public.inventory_usage for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "own rows" on public.fixed_expenses;
create policy "own rows" on public.fixed_expenses for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------- Storage bucket for per-project logos (used in-app and in printed reports) ----------

insert into storage.buckets (id, name, public)
values ('project-logos', 'project-logos', true)
on conflict (id) do nothing;

-- Anyone can read a logo (needed to display it and to embed it in printed PDFs).
drop policy if exists "project logos are publicly readable" on storage.objects;
create policy "project logos are publicly readable"
on storage.objects for select
using (bucket_id = 'project-logos');

-- A user can only upload/replace/delete logos stored under their own uid folder,
-- e.g. project-logos/{user_id}/{project_id}.png
drop policy if exists "users manage their own project logos" on storage.objects;
create policy "users manage their own project logos"
on storage.objects for all
using (bucket_id = 'project-logos' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'project-logos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Helpful indexes for the lookups the app does most often.
create index if not exists idx_daily_records_proj_date on public.daily_records (project_id, date);
create index if not exists idx_cost_usage_proj_date on public.cost_usage (project_id, date);
create index if not exists idx_cost_history_proj_item_month on public.cost_history (project_id, item_id, month);
create index if not exists idx_daily_expenses_proj_date on public.daily_expenses (project_id, date);
create index if not exists idx_inventory_usage_proj_date on public.inventory_usage (project_id, date);
