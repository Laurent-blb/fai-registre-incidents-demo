-- Correctif requis pour la suppression admin des incidents.
-- À exécuter dans Supabase SQL Editor.

-- 1) La table des pièces jointes manquait dans certains projets.
create table if not exists public.incident_attachments (
  id uuid primary key default gen_random_uuid(),
  incident_id text not null references public.incidents(id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text,
  file_size bigint,
  uploaded_by uuid references auth.users(id) on delete set null,
  uploaded_at timestamptz not null default now()
);
create index if not exists incident_attachments_incident_idx
  on public.incident_attachments(incident_id, uploaded_at desc);
alter table public.incident_attachments enable row level security;
drop policy if exists "Users read incident attachments" on public.incident_attachments;
create policy "Users read incident attachments" on public.incident_attachments
  for select to authenticated using (true);
drop policy if exists "Users add incident attachments" on public.incident_attachments;
create policy "Users add incident attachments" on public.incident_attachments
  for insert to authenticated with check (auth.uid() = uploaded_by);
drop policy if exists "Owners or admins delete incident attachments" on public.incident_attachments;
create policy "Owners or admins delete incident attachments" on public.incident_attachments
  for delete to authenticated using (uploaded_by = auth.uid() or public.is_admin());
insert into storage.buckets (id, name, public)
values ('incident-attachments', 'incident-attachments', false)
on conflict (id) do nothing;

-- 2) Les audits de suppression restent consultables sans conserver une FK
-- obligatoire vers une ligne d’incident qui vient d’être supprimée.
alter table public.incident_audit alter column incident_id drop not null;
alter table public.incident_audit drop constraint if exists incident_audit_incident_id_fkey;
alter table public.incident_audit
  add constraint incident_audit_incident_id_fkey
  foreign key (incident_id) references public.incidents(id) on delete set null;

-- 3) Lors d’une suppression, conserver l’ancien incident dans old_data,
-- mais laisser incident_id à NULL pour respecter la FK.
create or replace function public.audit_incident_changes()
returns trigger language plpgsql security definer set search_path = public as $$
declare changed jsonb := '{}'::jsonb; k text; oldv text; newv text;
begin
  if tg_op = 'INSERT' then
    insert into public.incident_audit(incident_id, action, changed_by, new_data)
    values (new.id, 'created', auth.uid(), to_jsonb(new));
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.incident_audit(incident_id, action, changed_by, old_data)
    values (null, 'deleted', auth.uid(), to_jsonb(old));
    return old;
  else
    for k in select key from jsonb_each(to_jsonb(new)) loop
      oldv := to_jsonb(old)->>k; newv := to_jsonb(new)->>k;
      if oldv is distinct from newv then
        changed := changed || jsonb_build_object(k, jsonb_build_object('old', oldv, 'new', newv));
      end if;
    end loop;
    insert into public.incident_audit(incident_id, action, changed_by, changed_fields, old_data, new_data)
    values (new.id, 'updated', auth.uid(), changed, to_jsonb(old), to_jsonb(new));
    return new;
  end if;
end; $$;

-- 4) Endpoint sécurisé utilisé par le bouton Supprimer.
create or replace function public.delete_incident_admin(target_incident_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Suppression réservée à un administrateur';
  end if;
  delete from public.incidents where id = target_incident_id;
end; $$;
revoke all on function public.delete_incident_admin(text) from public, anon;
grant execute on function public.delete_incident_admin(text) to authenticated;
