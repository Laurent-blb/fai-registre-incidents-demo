-- FAI Registre Incidents
-- À exécuter une seule fois dans Supabase > SQL Editor.

create table if not exists public.incidents (
  id text primary key,
  date_ouverture timestamptz not null,
  source text not null default 'Autre',
  client text not null,
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

create index if not exists incidents_date_ouverture_idx on public.incidents (date_ouverture desc);
create index if not exists incidents_statut_idx on public.incidents (statut);
create index if not exists incidents_priorite_idx on public.incidents (priorite);

alter table public.incidents enable row level security;

-- Tout visiteur peut consulter les incidents.
drop policy if exists "Incidents visibles publiquement" on public.incidents;
create policy "Incidents visibles publiquement"
  on public.incidents for select
  to anon, authenticated
  using (true);

-- Seuls les utilisateurs connectés peuvent créer, modifier ou supprimer.
drop policy if exists "Utilisateurs connectés créent des incidents" on public.incidents;
create policy "Utilisateurs connectés créent des incidents"
  on public.incidents for insert
  to authenticated
  with check (auth.uid() = created_by or created_by is null);

drop policy if exists "Utilisateurs connectés modifient des incidents" on public.incidents;
create policy "Utilisateurs connectés modifient des incidents"
  on public.incidents for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Utilisateurs connectés suppriment des incidents" on public.incidents;
create policy "Utilisateurs connectés suppriment des incidents"
  on public.incidents for delete
  to authenticated
  using (true);

create or replace function public.set_incident_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists incidents_updated_at on public.incidents;
create trigger incidents_updated_at
before update on public.incidents
for each row execute function public.set_incident_updated_at();
