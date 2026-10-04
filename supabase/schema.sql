-- FAI Registre Incidents
-- À exécuter dans Supabase > SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'user' check (role in ('admin', 'user')),
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
drop policy if exists "Users read their own profile" on public.profiles;
create policy "Users read their own profile" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
drop policy if exists "Admins update profiles" on public.profiles;
create policy "Admins update profiles" on public.profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name)
select id, coalesce(raw_user_meta_data->>'full_name', '')
from auth.users
on conflict (id) do nothing;

create table if not exists public.incidents (
  id text primary key,
  date_ouverture timestamptz not null,
  source text not null default 'Autre',
  client text not null,
  reporter_name text,
  reporter_phone text,
  reporter_email text,
  code_client text,
  site text,
  equipement text,
  nature text,
  ip text,
  localisation text,
  categorie text not null default 'Autre',
  priorite text not null default 'Moyenne',
  sla_heures integer not null default 24,
  echeance_sla timestamptz,
  responsable text,
  statut text not null default 'Ouvert',
  date_resolution timestamptz,
  duree_heures numeric,
  sla_respecte text,
  cause text,
  action text,
  escalade text,
  commentaires text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Migration non destructive pour les projets ayant déjà créé la table.
alter table public.incidents add column if not exists reporter_name text;
alter table public.incidents add column if not exists reporter_phone text;
alter table public.incidents add column if not exists reporter_email text;

create index if not exists incidents_date_ouverture_idx on public.incidents (date_ouverture desc);
create index if not exists incidents_statut_idx on public.incidents (statut);
create index if not exists incidents_priorite_idx on public.incidents (priorite);
alter table public.incidents enable row level security;

drop policy if exists "Incidents visibles publiquement" on public.incidents;
drop policy if exists "Incidents visibles aux utilisateurs connectés" on public.incidents;
create policy "Incidents visibles aux utilisateurs connectés" on public.incidents
  for select to authenticated using (true);

drop policy if exists "Utilisateurs connectés créent des incidents" on public.incidents;
create policy "Utilisateurs connectés créent des incidents" on public.incidents
  for insert to authenticated with check (auth.uid() = created_by);

drop policy if exists "Utilisateurs connectés modifient des incidents" on public.incidents;
create policy "Utilisateurs connectés modifient des incidents" on public.incidents
  for update to authenticated
  using (created_by = auth.uid() or public.is_admin())
  with check (created_by = auth.uid() or public.is_admin());

drop policy if exists "Utilisateurs connectés suppriment des incidents" on public.incidents;
create policy "Utilisateurs connectés suppriment des incidents" on public.incidents
  for delete to authenticated using (public.is_admin());

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

drop trigger if exists incidents_updated_at on public.incidents;
create trigger incidents_updated_at before update on public.incidents
for each row execute function public.set_updated_at();

create table if not exists public.session_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text,
  event_type text not null check (event_type in ('sign_in', 'sign_out')),
  user_agent text,
  platform text,
  occurred_at timestamptz not null default now()
);

create index if not exists session_events_occurred_at_idx on public.session_events (occurred_at desc);
create index if not exists session_events_user_id_idx on public.session_events (user_id);
alter table public.session_events enable row level security;

drop policy if exists "Users log their own session events" on public.session_events;
create policy "Users log their own session events" on public.session_events
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Admins read session events" on public.session_events;
create policy "Admins read session events" on public.session_events
  for select to authenticated using (public.is_admin());

-- Après création de votre premier compte, exécuter cette commande une seule fois
-- en remplaçant l'email :
-- update public.profiles set role = 'admin'
-- where id = (select id from auth.users where email = 'votre-email@example.com');
