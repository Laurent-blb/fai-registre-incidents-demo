-- Colonnes utilisées par le Dashboard et le formulaire avancé.
-- À exécuter dans Supabase SQL Editor si elles sont absentes.
alter table public.incidents add column if not exists region text;
alter table public.incidents add column if not exists first_response_at timestamptz;
alter table public.incidents add column if not exists reopened_count integer not null default 0;
alter table public.incidents add column if not exists last_status text;
notify pgrst, 'reload schema';
