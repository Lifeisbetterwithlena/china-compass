-- China Compass: per-user progress (ticked steps, saved steps/guides, settings).
-- Run once in the Supabase dashboard: SQL Editor → New query → paste → Run.

create table if not exists public.user_items (
  user_id    uuid        not null references auth.users (id) on delete cascade,
  kind       text        not null check (kind in ('checked', 'saved', 'setting')),
  key        text        not null check (char_length(key) <= 200),
  value      text                 check (char_length(value) <= 1000),
  -- Removals are kept as "deleted" rows so other devices learn about them.
  deleted    boolean     not null default false,
  -- Set by the app; the newest change to a key wins when devices sync.
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, key)
);

-- Row Level Security: every user can only see and change their own rows.
alter table public.user_items enable row level security;

drop policy if exists "Users read own items" on public.user_items;
create policy "Users read own items" on public.user_items
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users insert own items" on public.user_items;
create policy "Users insert own items" on public.user_items
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "Users update own items" on public.user_items;
create policy "Users update own items" on public.user_items
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete own items" on public.user_items;
create policy "Users delete own items" on public.user_items
  for delete to authenticated using ((select auth.uid()) = user_id);

revoke all on public.user_items from anon;
grant select, insert, update, delete on public.user_items to authenticated;

-- "Delete account" in the app: removes the signed-in user; their items go with it (on delete cascade).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
