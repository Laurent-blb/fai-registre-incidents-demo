-- Synchronisation des comptes Auth vers la table visible par l’administration.
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists status text not null default 'active' check (status in ('active','suspended'));
alter table public.profiles add column if not exists last_seen_at timestamptz;

create or replace function public.sync_profiles_from_auth()
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Accès réservé à un administrateur';
  end if;
  insert into public.profiles (id, email, full_name, status)
  select id, email, coalesce(raw_user_meta_data->>'full_name',''), 'active'
  from auth.users
  on conflict (id) do update set
    email = excluded.email,
    full_name = case when coalesce(public.profiles.full_name,'')='' then excluded.full_name else public.profiles.full_name end,
    updated_at = now();
end; $$;
revoke all on function public.sync_profiles_from_auth() from public, anon;
grant execute on function public.sync_profiles_from_auth() to authenticated;

-- Autoriser l’administration à consulter tout l’historique.
drop policy if exists "Admins read all profiles" on public.profiles;
create policy "Admins read all profiles" on public.profiles
  for select to authenticated using (public.is_admin());
drop policy if exists "Admins read session events" on public.session_events;
create policy "Admins read session events" on public.session_events
  for select to authenticated using (public.is_admin());
