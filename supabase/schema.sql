-- ============================================================
-- Tuition Manager — complete database schema
-- Derived from every model/repository in lib/ (single source of truth).
--
-- WARNING: the DROP statements at the top delete ALL existing data
-- in these 5 tables. Only run on a fresh start / disposable data.
--
-- How to run: Supabase Dashboard → SQL Editor → New query →
-- paste this whole file → Run.
-- ============================================================

-- ── 1. Wipe old tables (children first) ──────────────────────
drop table if exists public.attendance cascade;
drop table if exists public.fees        cascade;
drop table if exists public.routines    cascade;
drop table if exists public.students    cascade;
drop table if exists public.teachers    cascade;

-- ── 2. teachers ──────────────────────────────────────────────
create table public.teachers (
  id           uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  full_name    text not null default '',
  phone        text not null unique,
  email        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ── 3. students (teacher_id = auth.users.id, set by the app) ─
create table public.students (
  id             uuid primary key default gen_random_uuid(),
  teacher_id     uuid references auth.users(id) on delete set null,
  name           text not null default '',
  phone          text,
  parent_name    text,
  guardian_phone text,
  address        text,
  class_name     text,
  subject        text,
  monthly_fee    double precision not null default 0,
  schedule       text,
  admission_date date,
  is_active      boolean not null default true,
  notes          text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ── 4. attendance (one row per student per day) ──────────────
create table public.attendance (
  id         uuid primary key default gen_random_uuid(),
  teacher_id uuid references auth.users(id) on delete set null,
  student_id uuid not null references public.students(id) on delete cascade,
  date       date not null,
  status     text not null default 'Present',
  note       text,
  created_at timestamptz not null default now(),
  constraint uq_attendance_student_date unique (student_id, date)
);

-- ── 5. fees (one row per student per month, month = 'YYYY-MM') ─
create table public.fees (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid references auth.users(id) on delete set null,
  student_id  uuid not null references public.students(id) on delete cascade,
  month       text not null,               -- 'YYYY-MM'
  amount      double precision not null default 0,
  paid_amount double precision not null default 0,
  status      text not null default 'Due', -- 'Due' | 'Partial' | 'Paid'
  paid_date   timestamptz,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint uq_fees_student_month unique (student_id, month)
);

-- ── 6. routines ──────────────────────────────────────────────
create table public.routines (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid references auth.users(id) on delete set null,
  class_name  text not null default '',
  day         text,
  day_of_week integer not null default 1,
  time        text,
  start_time  text,
  end_time    text,
  topic       text,
  location    text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ── 7. Row Level Security ────────────────────────────────────
alter table public.teachers   enable row level security;
alter table public.students   enable row level security;
alter table public.attendance enable row level security;
alter table public.fees       enable row level security;
alter table public.routines   enable row level security;

-- teachers: anyone may READ (the app checks for duplicate phone
-- numbers BEFORE signing in); writes are limited to own record.
create policy "teachers_select" on public.teachers
  for select using (true);
create policy "teachers_insert_own" on public.teachers
  for insert with check (auth.uid() = auth_user_id);
create policy "teachers_update_own" on public.teachers
  for update using (auth.uid() = auth_user_id)
  with check (auth.uid() = auth_user_id);
create policy "teachers_delete_own" on public.teachers
  for delete using (auth.uid() = auth_user_id);

-- The app queries these tables globally (no per-teacher filter),
-- so any signed-in user (incl. anonymous) gets full access.
create policy "students_full_access"   on public.students
  for all to authenticated using (true) with check (true);
create policy "attendance_full_access" on public.attendance
  for all to authenticated using (true) with check (true);
create policy "fees_full_access"       on public.fees
  for all to authenticated using (true) with check (true);
create policy "routines_full_access"   on public.routines
  for all to authenticated using (true) with check (true);

-- ── 8. Indexes ───────────────────────────────────────────────
create index idx_students_teacher_id   on public.students(teacher_id);
create index idx_students_name         on public.students(name);
create index idx_attendance_student_id on public.attendance(student_id);
create index idx_attendance_date       on public.attendance(date);
create index idx_fees_student_id       on public.fees(student_id);
create index idx_fees_month            on public.fees(month);
create index idx_routines_teacher_id   on public.routines(teacher_id);

-- ── 9. Realtime (required for .stream() on students/routines) ─
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'students') then
    execute 'alter publication supabase_realtime add table public.students';
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'routines') then
    execute 'alter publication supabase_realtime add table public.routines';
  end if;
end $$;
