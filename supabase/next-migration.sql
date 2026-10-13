-- Migration complémentaire : profils administrables, sécurité et audit des incidents.
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists status text not null default 'active' check (status in ('active','suspended'));
alter table public.profiles add column if not exists last_seen_at timestamptz;
update public.profiles p set email=u.email from auth.users u where u.id=p.id and p.email is null;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''))
  on conflict (id) do update set email=excluded.email;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

drop policy if exists "Admins read all profiles" on public.profiles;
create policy "Admins read all profiles" on public.profiles for select to authenticated using (public.is_admin());
drop policy if exists "Admins update profiles" on public.profiles;
create policy "Admins update profiles" on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(), event_type text not null,
  email text, user_id uuid references auth.users(id) on delete set null,
  ip_address inet, user_agent text, metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(), acknowledged_at timestamptz, acknowledged_by uuid references auth.users(id)
);
create index if not exists security_events_occurred_at_idx on public.security_events(occurred_at desc);
alter table public.security_events enable row level security;
drop policy if exists "Admins read security events" on public.security_events;
create policy "Admins read security events" on public.security_events for select to authenticated using (public.is_admin());

create table if not exists public.incident_audit (
  id uuid primary key default gen_random_uuid(), incident_id text not null references public.incidents(id) on delete cascade,
  action text not null check (action in ('created','updated','deleted')), changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(), changed_fields jsonb not null default '{}'::jsonb,
  old_data jsonb, new_data jsonb
);
create index if not exists incident_audit_incident_idx on public.incident_audit(incident_id, changed_at desc);
alter table public.incident_audit enable row level security;
drop policy if exists "Users read incident audit" on public.incident_audit;
create policy "Users read incident audit" on public.incident_audit for select to authenticated using (true);

create or replace function public.audit_incident_changes()
returns trigger language plpgsql security definer set search_path = public as $$
declare changed jsonb := '{}'::jsonb; k text; oldv text; newv text;
begin
  if tg_op='INSERT' then
    insert into public.incident_audit(incident_id,action,changed_by,new_data) values(new.id,'created',auth.uid(),to_jsonb(new)); return new;
  elsif tg_op='DELETE' then
    insert into public.incident_audit(incident_id,action,changed_by,old_data) values(old.id,'deleted',auth.uid(),to_jsonb(old)); return old;
  else
    for k in select key from jsonb_each(to_jsonb(new)) loop
      oldv:=to_jsonb(old)->>k; newv:=to_jsonb(new)->>k;
      if oldv is distinct from newv then changed:=changed || jsonb_build_object(k,jsonb_build_object('old',oldv,'new',newv)); end if;
    end loop;
    insert into public.incident_audit(incident_id,action,changed_by,changed_fields,old_data,new_data) values(new.id,'updated',auth.uid(),changed,to_jsonb(old),to_jsonb(new)); return new;
  end if;
end; $$;
drop trigger if exists incidents_audit_trigger on public.incidents;
create trigger incidents_audit_trigger after insert or update or delete on public.incidents for each row execute function public.audit_incident_changes();

-- Amorçage du premier administrateur.
-- Pour des raisons de sécurité, ne créez pas auth.users et ne stockez jamais un mot de passe en clair dans une migration.
-- 1) Créez d'abord le compte dans Supabase > Authentication > Users avec son email et son mot de passe temporaire.
-- 2) Exécutez ensuite : select public.promote_user_to_admin('admin@exemple.com');
create or replace function public.promote_user_to_admin(target_email text)
returns uuid language plpgsql security definer set search_path=public as $$
declare target_id uuid;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Seul un administrateur peut promouvoir un utilisateur';
  end if;
  select id into target_id from auth.users where lower(email)=lower(target_email) limit 1;
  if target_id is null then raise exception 'Aucun compte Auth trouvé pour cet email'; end if;
  insert into public.profiles(id,email,role,status) values(target_id,target_email,'admin','active')
  on conflict(id) do update set role='admin',status='active',email=excluded.email,updated_at=now();
  return target_id;
end; $$;
revoke all on function public.promote_user_to_admin(text) from public, anon, authenticated;
