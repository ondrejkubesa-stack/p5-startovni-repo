-- seed.sql · demo data P5.2 · v1.1 · smyšlená firma Truhlářství Dub, žádné osobní údaje
-- Spouští se jen v DEV projektu (SQL Editor nebo `supabase db reset` lokálně). Do produkce nikdy.
-- Test anonymního čtení potřebuje aspoň 1 řádek: test nad prázdnou tabulkou nic nedokazuje.
-- Idempotentní: vloží demo řádky jen do prázdné tabulky, opakované spuštění nic nezdvojí.
-- Playwright test při každém běhu přidá řádek „Testovací skříň do předsíně …“. Úklid v dev projektu:
--   delete from public.poptavky where popis like 'Testovací skříň do předsíně %';

insert into public.poptavky (prijato, kanal, popis, odhad_kc, stav, termin_zamereni)
select v.prijato, v.kanal, v.popis, v.odhad_kc, v.stav, v.termin_zamereni
from (values
  (current_date - 9, 'web',     'Vestavěná skříň do předsíně, šířka 2,5 m, posuvné dveře se zrcadlem', 40230::integer, 'nabidka',  null::date),
  (current_date - 6, 'telefon', 'Kuchyňská linka do chaty, dvířka masiv, bez spotřebičů',             null,           'zamereni', current_date + 3),
  (current_date - 4, 'e-mail',  'Oprava dvířek u šatní skříně, 2 panty',                              1500,           'vyhrano',  null),
  (current_date - 2, 'web',     'Knihovna do pracovny přes celou stěnu, 3,8 m',                        null,           'zamereni', current_date + 1),
  (current_date - 1, 'osobne',  'Botník do úzké chodby, hloubka max. 25 cm',                           null,           'nova',     null),
  (current_date,     'web',     'Postel z dubu 180 × 200 s úložným prostorem',                         null,           'nova',     null)
) as v(prijato, kanal, popis, odhad_kc, stav, termin_zamereni)
where not exists (select 1 from public.poptavky);
