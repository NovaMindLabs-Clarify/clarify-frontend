-- Аватарки после загрузки показывали чёрный кружок вместо картинки и на вебе,
-- и на телефоне (фидбек пользователя 2026-08-01) — Supabase Storage бакет
-- `avatars` не был публично читаемым: uploadBinary()/getPublicUrl() в
-- account_settings_dialog.dart и main.dart отрабатывают без ошибки, но сама
-- ссылка требует авторизации, и NetworkImage тихо проваливается, оставляя
-- только фоновый цвет CircleAvatar (в тёмной теме — почти чёрный).
--
-- Простейший путь — включить тумблер "Public bucket" в Supabase Dashboard →
-- Storage → avatars → Configuration. Этот файл — SQL-эквивалент того же
-- эффекта (публичное чтение объектов конкретно в бакете `avatars`, без
-- публичной записи) — на случай, если тумблер в интерфейсе недоступен или
-- предпочтителен явный, версионируемый SQL.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars_authenticated_write" on storage.objects;
create policy "avatars_authenticated_write"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

drop policy if exists "avatars_authenticated_update" on storage.objects;
create policy "avatars_authenticated_update"
  on storage.objects for update
  using (bucket_id = 'avatars' and auth.role() = 'authenticated');
