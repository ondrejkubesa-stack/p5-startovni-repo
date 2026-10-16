-- 0000_vychozi_prava.sql · šablona P5.2 · v1.1 · ověřeno k 2026-10-07 · vlastník OK
-- Zdroj: https://supabase.com/docs/guides/api/securing-your-api (oddíl „Revoke default privileges“), volatilní.
-- Proč: revoke v 0001 platí jen pro tabulku poptavky. Tabulka naklikaná v dashboardu, nová funkce nebo sekvence
-- by jinak dostala práva pro anon a authenticated automaticky. Po této migraci nový objekt v public
-- nikomu z klientských rolí nic nedovolí, dokud mu práva nedáš výslovně (grant) v migraci.
-- service_role (server se secret klíčem) práva ponechává, aby nová tabulka nerozbila server; RLS ho stejně neomezuje.
-- Spouští se jednou na projekt (dev i budoucí produkce v P6), před 0001.

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;
