-- Motor de Conteúdo 90D · MarketipsBrasil · Fase 1
-- Execute este arquivo uma única vez no SQL Editor do Supabase.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name text not null check (char_length(trim(name)) > 1),
  niche text,
  objective text,
  tone_of_voice text,
  products text,
  restrictions text,
  primary_color text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  publish_date date not null,
  channel text not null check (channel in ('Instagram', 'Facebook', 'Google Meu Negócio')),
  format text not null check (format in ('Post', 'Carrossel', 'Reel', 'Story', 'Google Post')),
  title text not null check (char_length(trim(title)) > 2),
  status text not null default 'Ideia' check (status in ('Ideia', 'Em criação', 'Aprovar', 'Pronto', 'Publicado')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists clients_owner_id_idx on public.clients(owner_id);
create index if not exists content_items_owner_date_idx on public.content_items(owner_id, publish_date);
create index if not exists content_items_client_id_idx on public.content_items(client_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists clients_updated_at on public.clients;
create trigger clients_updated_at before update on public.clients
for each row execute function public.set_updated_at();

drop trigger if exists content_items_updated_at on public.content_items;
create trigger content_items_updated_at before update on public.content_items
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.content_items enable row level security;

drop policy if exists "Users view own profile" on public.profiles;
create policy "Users view own profile" on public.profiles for select using (id = auth.uid());
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Users manage own clients" on public.clients;
create policy "Users manage own clients" on public.clients for all
using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "Users manage own content" on public.content_items;
create policy "Users manage own content" on public.content_items for all
using (owner_id = auth.uid()) with check (
  owner_id = auth.uid()
  and exists (select 1 from public.clients c where c.id = client_id and c.owner_id = auth.uid())
);
