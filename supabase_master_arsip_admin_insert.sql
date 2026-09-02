-- Allows Admin users to register physical archive documents from ArchivePage.
-- Run this in the Supabase SQL Editor once.
-- No table columns need to be added for the current ArchivePage form.

alter table public.master_arsip enable row level security;

drop policy if exists "master_arsip_select_authenticated"
on public.master_arsip;

create policy "master_arsip_select_authenticated"
on public.master_arsip
for select
to authenticated
using (true);

drop policy if exists "master_arsip_insert_admin"
on public.master_arsip;

create policy "master_arsip_insert_admin"
on public.master_arsip
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
      and profiles.role = 'admin'
  )
);

notify pgrst, 'reload schema';
