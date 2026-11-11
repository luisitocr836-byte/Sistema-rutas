-- Simula lo mínimo de Supabase para probar las migraciones en un PostgreSQL local con PostGIS.
-- NO se usa en Supabase real (allí estos objetos ya existen).
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid());
create or replace function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create publication supabase_realtime;
create schema if not exists extensions;
grant usage on schema public, extensions, auth to anon, authenticated, service_role;
grant select on auth.users to service_role;
