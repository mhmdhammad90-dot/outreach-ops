-- عمليات Outreach: إعداد قاعدة البيانات
create table if not exists public.records (
  collection text not null check (collection in ('ops','staff','settings')),
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  primary key (collection, id)
);
create table if not exists public.members (
  email text primary key,
  name text,
  role text not null default 'editor' check (role in ('editor','admin')),
  added_at timestamptz not null default now()
);
alter table public.records enable row level security;
alter table public.members enable row level security;

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.members where lower(email) = lower(coalesce(auth.jwt()->>'email',''))
$$;
grant execute on function public.my_role() to anon, authenticated;

drop policy if exists "records read" on public.records;
drop policy if exists "records insert" on public.records;
drop policy if exists "records update" on public.records;
drop policy if exists "records delete" on public.records;
create policy "records read" on public.records for select using (true);
create policy "records insert" on public.records for insert to authenticated
  with check (public.my_role() = 'admin' or (public.my_role() = 'editor' and collection <> 'settings'));
create policy "records update" on public.records for update to authenticated
  using (public.my_role() = 'admin' or (public.my_role() = 'editor' and collection <> 'settings'))
  with check (public.my_role() = 'admin' or (public.my_role() = 'editor' and collection <> 'settings'));
create policy "records delete" on public.records for delete to authenticated
  using (public.my_role() = 'admin');

drop policy if exists "members read" on public.members;
drop policy if exists "members write" on public.members;
create policy "members read" on public.members for select to authenticated
  using (public.my_role() is not null);
create policy "members write" on public.members for all to authenticated
  using (public.my_role() = 'admin') with check (public.my_role() = 'admin');

do $$ begin
  alter publication supabase_realtime add table public.records;
exception when duplicate_object then null; end $$;
alter table public.records replica identity full;

insert into public.records (collection, id, data) values
('ops','op-mw91mkcktlbo','{"code": "OUT-2026-106", "date": "2026-11-10", "clinic": "CLN-001", "point": "LOC-001", "service": "Nutrition", "status": "Planned", "dep": "09:00", "ret": "13:00", "leader": "st-ahmad", "notes": "", "team": [{"id": "st-ahmad", "name": "أحمد طموس", "role": "CHNP", "phone": "0598981610"}, {"id": "st-dalia", "name": "داليا بعلوشة", "role": "CHNP", "phone": ""}, {"id": "st-mhabeel", "name": "محمد الهبيل", "role": "CHNP", "phone": ""}], "createdAt": "2026-11-09T09:13:05.182Z", "updatedAt": "2026-11-09T09:30:05.046Z"}'::jsonb),
('staff','st-ahmad','{"name": "أحمد طموس", "role": "CHNP", "clinic": "CLN-001", "phone": "0598981610"}'::jsonb),
('staff','st-dalia','{"name": "داليا بعلوشة", "role": "CHNP", "clinic": "CLN-001", "phone": ""}'::jsonb),
('staff','st-mhabeel','{"name": "محمد الهبيل", "role": "CHNP", "clinic": "CLN-001", "phone": ""}'::jsonb)
on conflict (collection, id) do nothing;

-- المشرف الأول
insert into public.members (email, name, role) values ('mhmd.hammad90@gmail.com', 'المشرف', 'admin')
on conflict (email) do update set role = 'admin';
