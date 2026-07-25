-- Кастомный интервал повтора задачи (MISSING_FEATURES.md P1.1) — recurrence='custom'
-- хранит число дней между повторами в этой колонке; для daily/weekdays/weekly/monthly
-- она не используется.
alter table public.tasks add column if not exists recurrence_interval integer;
