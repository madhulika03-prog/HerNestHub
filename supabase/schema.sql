-- Supabase schema for HerNest Hub
-- Run this in the Supabase SQL editor or via the supabase CLI.

-- Enable pgcrypto for gen_random_uuid()
create extension if not exists "pgcrypto";

-- Enums
create type booking_status as enum ('pending', 'confirmed', 'cancelled');
create type request_status as enum ('pending', 'approved', 'rejected', 'closed');

-- Helper: update timestamp trigger
create or replace function trigger_set_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Customers
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists customers_email_idx on customers(email);
create trigger set_timestamp_customers
  before update on customers
  for each row
  execute procedure trigger_set_timestamp();

-- Rooms
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  floor int,
  description text,
  capacity int,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create trigger set_timestamp_rooms
  before update on rooms
  for each row
  execute procedure trigger_set_timestamp();

-- Beds
create table if not exists beds (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id) on delete cascade,
  bed_label text,
  sharing_type text,
  price numeric(10,2),
  is_available boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists beds_room_idx on beds(room_id);
create trigger set_timestamp_beds
  before update on beds
  for each row
  execute procedure trigger_set_timestamp();

-- Packages
create table if not exists packages (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(10,2) not null default 0,
  duration_months int not null default 1,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create trigger set_timestamp_packages
  before update on packages
  for each row
  execute procedure trigger_set_timestamp();

-- Bookings
create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id),
  package_id uuid references packages(id),
  room_id uuid references rooms(id),
  bed_id uuid references beds(id),
  move_in_date date,
  status booking_status default 'pending',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists bookings_customer_idx on bookings(customer_id);
create index if not exists bookings_room_idx on bookings(room_id);
create trigger set_timestamp_bookings
  before update on bookings
  for each row
  execute procedure trigger_set_timestamp();

-- PG Visit Requests
create table if not exists pg_visit_requests (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  email text,
  phone text,
  preferred_room_id uuid references rooms(id),
  visit_datetime timestamptz,
  message text,
  status request_status default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create trigger set_timestamp_pg_visits
  before update on pg_visit_requests
  for each row
  execute procedure trigger_set_timestamp();

-- Inquiries / Contact Requests
create table if not exists inquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text,
  message text,
  status request_status default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create trigger set_timestamp_inquiries
  before update on inquiries
  for each row
  execute procedure trigger_set_timestamp();

-- Row Level Security (RLS) notes and example policies
-- IMPORTANT: tailor these policies to your auth setup. The examples below are conservative and intended as a starting point.

-- Enable RLS on tables that will be written from the client
alter table bookings enable row level security;
alter table pg_visit_requests enable row level security;
alter table inquiries enable row level security;

-- Example: allow anonymous inserts for bookings/visits/inquiries but disallow selects/updates/deletes from anon users.
-- Replace these with stricter rules for production (e.g., require auth.uid() or custom JWT claims).

create policy "public_insert_bookings" on bookings
  for insert
  using (true)
  with check (true);

create policy "public_insert_pg_visits" on pg_visit_requests
  for insert
  using (true)
  with check (true);

create policy "public_insert_inquiries" on inquiries
  for insert
  using (true)
  with check (true);

-- Do NOT allow anon users to update or delete bookings/visits/inquiries. Admins should use server-side functions (Edge Functions) with the service role key to perform privileged updates.

-- Example admin-only update policy (requires auth.role() = 'authenticated' and a custom claim 'is_admin' = true):
-- create policy "admin_update" on bookings for update using (auth.role() = 'authenticated' and (current_setting('request.jwt.claims', true) ->> 'is_admin')::boolean = true);

-- END OF SCHEMA
