-- Qualité du registre, pièces jointes, alertes et indicateurs avancés.
alter table public.incidents add column if not exists region text;
alter table public.incidents add column if not exists first_response_at timestamptz;
alter table public.incidents add column if not exists reopened_count integer not null default 0;
alter table public.incidents add column if not exists last_status text;

create table if not exists public.incident_attachments (
  id uuid primary key default gen_random_uuid(), incident_id text not null references public.incidents(id) on delete cascade,
  storage_path text not null unique, file_name text not null, mime_type text, file_size bigint,
  uploaded_by uuid references auth.users(id) on delete set null, uploaded_at timestamptz not null default now()
);
create index if not exists incident_attachments_incident_idx on public.incident_attachments(incident_id, uploaded_at desc);
alter table public.incident_attachments enable row level security;
drop policy if exists "Users read incident attachments" on public.incident_attachments;
create policy "Users read incident attachments" on public.incident_attachments for select to authenticated using (true);
drop policy if exists "Users add incident attachments" on public.incident_attachments;
create policy "Users add incident attachments" on public.incident_attachments for insert to authenticated with check (auth.uid()=uploaded_by);
drop policy if exists "Owners or admins delete incident attachments" on public.incident_attachments;
create policy "Owners or admins delete incident attachments" on public.incident_attachments for delete to authenticated using (uploaded_by=auth.uid() or public.is_admin());

insert into storage.buckets (id,name,public) values ('incident-attachments','incident-attachments',false) on conflict (id) do nothing;
drop policy if exists "Authenticated read incident files" on storage.objects;
create policy "Authenticated read incident files" on storage.objects for select to authenticated using (bucket_id='incident-attachments');
drop policy if exists "Authenticated upload incident files" on storage.objects;
create policy "Authenticated upload incident files" on storage.objects for insert to authenticated with check (bucket_id='incident-attachments');
drop policy if exists "Owner or admin delete incident files" on storage.objects;
create policy "Owner or admin delete incident files" on storage.objects for delete to authenticated using (bucket_id='incident-attachments' and (owner=auth.uid() or public.is_admin()));

create table if not exists public.security_alerts (
  id uuid primary key default gen_random_uuid(), alert_type text not null, severity text not null check (severity in ('information','attention','critical')),
  title text not null, details text, incident_id text references public.incidents(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null, status text not null default 'open' check (status in ('open','acknowledged','resolved')),
  fingerprint text not null unique, created_at timestamptz not null default now(), acknowledged_at timestamptz, acknowledged_by uuid references auth.users(id)
);
create index if not exists security_alerts_status_idx on public.security_alerts(status, created_at desc);
alter table public.security_alerts enable row level security;
drop policy if exists "Admins read alerts" on public.security_alerts;
create policy "Admins read alerts" on public.security_alerts for select to authenticated using (public.is_admin());
drop policy if exists "Admins update alerts" on public.security_alerts;
create policy "Admins update alerts" on public.security_alerts for update to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.refresh_incident_quality_alerts() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.priorite='Critique' and coalesce(new.responsable,'')='' then
    insert into public.security_alerts(alert_type,severity,title,details,incident_id,fingerprint)
    values('critical_unassigned','critical','Incident critique sans responsable','Une affectation est requise.',new.id,'critical_unassigned:'||new.id)
    on conflict(fingerprint) do update set status='open',details=excluded.details;
  else
    update public.security_alerts set status='resolved' where fingerprint='critical_unassigned:'||new.id and status<>'resolved';
  end if;
  if new.statut in ('Ouvert','En cours') and now()>coalesce(new.echeance_sla,now()) then
    insert into public.security_alerts(alert_type,severity,title,details,incident_id,fingerprint)
    values('sla_breach','attention','Incident hors SLA','La date d’échéance est dépassée.',new.id,'sla_breach:'||new.id)
    on conflict(fingerprint) do update set status='open',details=excluded.details;
  end if;
  return new;
end; $$;
drop trigger if exists incidents_quality_alerts_trigger on public.incidents;
create trigger incidents_quality_alerts_trigger after insert or update on public.incidents for each row execute function public.refresh_incident_quality_alerts();
