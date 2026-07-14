-- ============================================================
-- WafferApp — Supabase schema
-- نفّذ هذا الملف في: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1) profiles  (بيانات المستخدم الإضافية فوق auth.users)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  name text,
  email text,
  monthly_income numeric default 0,
  currency text default 'SAR',
  language text default 'ar',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);


-- ─────────────────────────────────────────────────────────────
-- 2) categories  (فئات عامة افتراضية + فئات خاصة بالمستخدم)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.categories (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade, -- null = فئة عامة (افتراضية)
  name text not null,
  name_ar text,
  name_en text,
  slug text,
  icon text,
  color text,
  type text not null default 'expense' check (type in ('expense','income','saving')),
  is_default boolean default false,
  sort_order int default 0,
  created_at timestamptz default now()
);

alter table public.categories enable row level security;

-- يرى المستخدم الفئات العامة (user_id is null) + فئاته الخاصة
create policy "categories_select" on public.categories
  for select using (user_id is null or auth.uid() = user_id);
create policy "categories_insert_own" on public.categories
  for insert with check (auth.uid() = user_id);
create policy "categories_update_own" on public.categories
  for update using (auth.uid() = user_id);
create policy "categories_delete_own" on public.categories
  for delete using (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 3) transactions
-- ─────────────────────────────────────────────────────────────
create table if not exists public.transactions (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id bigint references public.categories(id) on delete set null,
  saving_goal_id bigint, -- FK تُضاف بعد إنشاء جدول saving_goals
  budget_id bigint,
  amount numeric not null,
  currency text default 'SAR',
  type text not null check (type in ('expense','income','saving')),
  description text default '',
  merchant text default '',
  source text default 'manual',
  reference text default '',
  transaction_date date not null default current_date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.transactions enable row level security;

create policy "transactions_all_own" on public.transactions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_transactions_user_date
  on public.transactions(user_id, transaction_date desc);
create index if not exists idx_transactions_category
  on public.transactions(category_id);
create index if not exists idx_transactions_saving_goal
  on public.transactions(saving_goal_id);


-- ─────────────────────────────────────────────────────────────
-- 4) saving_goals
-- ─────────────────────────────────────────────────────────────
create table if not exists public.saving_goals (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text default '',
  icon text default '',
  color text default '',
  target_amount numeric not null default 0,
  current_amount numeric not null default 0,
  currency text default 'SAR',
  start_date date default current_date,
  deadline date,
  status text not null default 'active' check (status in ('active','paused','cancelled','achieved')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.saving_goals enable row level security;

create policy "saving_goals_all_own" on public.saving_goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- الآن نضيف FK على transactions.saving_goal_id
alter table public.transactions
  add constraint fk_transactions_saving_goal
  foreign key (saving_goal_id) references public.saving_goals(id) on delete set null;


-- ─────────────────────────────────────────────────────────────
-- 5) budgets + budget_categories
-- ─────────────────────────────────────────────────────────────
create table if not exists public.budgets (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  month int not null,
  year int not null,
  period_start date not null,
  period_end date not null,
  total_income numeric default 0,
  total_amount numeric not null default 0,
  currency text default 'SAR',
  status text not null default 'active' check (status in ('active','closed','draft')),
  notes text default '',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, month, year)
);

alter table public.budgets enable row level security;

create policy "budgets_all_own" on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.budget_categories (
  id bigint generated always as identity primary key,
  budget_id bigint not null references public.budgets(id) on delete cascade,
  category_id bigint not null references public.categories(id) on delete cascade,
  allocated_amount numeric not null default 0,
  alert_threshold int default 80,
  created_at timestamptz default now()
);

alter table public.budget_categories enable row level security;

-- الوصول مبني على ملكية الميزانية الأم
create policy "budget_categories_all_via_budget" on public.budget_categories
  for all using (
    exists (select 1 from public.budgets b where b.id = budget_id and b.user_id = auth.uid())
  )
  with check (
    exists (select 1 from public.budgets b where b.id = budget_id and b.user_id = auth.uid())
  );

create index if not exists idx_budget_categories_budget on public.budget_categories(budget_id);

-- ربط transactions.budget_id بالميزانية (اختياري)
alter table public.transactions
  add constraint fk_transactions_budget
  foreign key (budget_id) references public.budgets(id) on delete set null;


-- ─────────────────────────────────────────────────────────────
-- 6) monthly_summaries  (سجلات إقفال الشهر)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.monthly_summaries (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  year int not null,
  month int not null,
  period_start date not null,
  period_end date not null,
  currency text default 'SAR',
  allocation_status text not null default 'unallocated'
    check (allocation_status in ('unallocated','partially_allocated','fully_allocated')),
  allocated_amount numeric default 0,
  unallocated_remaining numeric default 0,
  closed_at timestamptz,
  closed_by text default '',
  notes text default '',
  created_at timestamptz default now(),
  unique (user_id, year, month)
);

alter table public.monthly_summaries enable row level security;

create policy "monthly_summaries_all_own" on public.monthly_summaries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 7) notifications
-- ─────────────────────────────────────────────────────────────
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null default 'system',
  severity text not null default 'info' check (severity in ('info','success','warning','error')),
  title text default '',
  title_ar text default '',
  title_en text default '',
  message text default '',
  message_ar text default '',
  message_en text default '',
  icon text default '',
  is_read boolean default false,
  read_at timestamptz,
  deeplink text,
  payload jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

alter table public.notifications enable row level security;

create policy "notifications_all_own" on public.notifications
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists idx_notifications_user_unread
  on public.notifications(user_id, is_read);


-- ─────────────────────────────────────────────────────────────
-- 8) devices  (FCM push tokens)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.devices (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null default 'android',
  device_name text,
  device_model text,
  app_version text,
  locale text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.devices enable row level security;

-- يسمح بالتسجيل كضيف (user_id = null) ثم ربطه بالمستخدم بعد تسجيل الدخول
create policy "devices_insert_any" on public.devices
  for insert with check (true);
create policy "devices_select_own" on public.devices
  for select using (user_id is null or auth.uid() = user_id);
create policy "devices_update_own_or_link" on public.devices
  for update using (user_id is null or auth.uid() = user_id)
  with check (user_id is null or auth.uid() = user_id);


-- ─────────────────────────────────────────────────────────────
-- 9) trigger: تحديث updated_at تلقائياً
-- ─────────────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_transactions_updated before update on public.transactions
  for each row execute function public.set_updated_at();
create trigger trg_saving_goals_updated before update on public.saving_goals
  for each row execute function public.set_updated_at();
create trigger trg_budgets_updated before update on public.budgets
  for each row execute function public.set_updated_at();
create trigger trg_devices_updated before update on public.devices
  for each row execute function public.set_updated_at();


-- ─────────────────────────────────────────────────────────────
-- 10) فئات افتراضية (يراها كل المستخدمين، user_id = null)
-- ─────────────────────────────────────────────────────────────
insert into public.categories (name, name_ar, name_en, slug, icon, color, type, is_default, sort_order) values
  ('طعام وشراب', 'طعام وشراب', 'Food & Drinks', 'food', 'restaurant', '#FF9800', 'expense', true, 1),
  ('تسوق', 'تسوق', 'Shopping', 'shopping', 'shopping_bag', '#E91E63', 'expense', true, 2),
  ('مواصلات', 'مواصلات', 'Transport', 'transport', 'directions_car', '#3F51B5', 'expense', true, 3),
  ('فواتير', 'فواتير', 'Bills', 'bills', 'receipt_long', '#795548', 'expense', true, 4),
  ('صحة', 'صحة', 'Health', 'health', 'local_hospital', '#F44336', 'expense', true, 5),
  ('ترفيه', 'ترفيه', 'Entertainment', 'entertainment', 'sports_esports', '#9C27B0', 'expense', true, 6),
  ('تعليم', 'تعليم', 'Education', 'education', 'school', '#2196F3', 'expense', true, 7),
  ('أخرى', 'أخرى', 'Other', 'other', 'category', '#607D8B', 'expense', true, 8),
  ('راتب', 'راتب', 'Salary', 'salary', 'payments', '#4CAF50', 'income', true, 1),
  ('دخل إضافي', 'دخل إضافي', 'Other Income', 'other_income', 'attach_money', '#8BC34A', 'income', true, 2),
  ('ادخار', 'ادخار', 'Saving', 'saving', 'savings', '#009688', 'saving', true, 1)
on conflict do nothing;


-- ─────────────────────────────────────────────────────────────
-- 11) trigger: إنشاء صف profiles تلقائياً عند تسجيل مستخدم جديد
-- ─────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, phone)
  values (new.id, new.phone)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- ملاحظة: SMS OTP يتطلب تفعيل مزوّد SMS (Twilio/Vonage/MessageBird)
-- من: Authentication → Providers → Phone في لوحة Supabase.
-- ============================================================
