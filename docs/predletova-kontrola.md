# Předletová kontrola: [DOPLŇ název nástroje]

<!-- Šablona P5.2 · v1.2 · ověřeno k 2026-10-12 · vlastník OK.
Vyplňuje člověk, ne agent. Každou položku zaškrtni [x] a napiš ANO, nebo NE + proč a co s tím uděláš.
V oddílech A až E je NE stop: brána neprojde, dokud to neopravíš a nenapíšeš ANO. N/A (nehodí se) schvaluje lektor.
NE s vysvětlením smí jen F a G. Nezaškrtnutá položka nebo nevyplněná značka DOPLŇ = kontrola neprošla (hlídá scripts/kontrola-p5.sh).
Brána do P6 a P8: plný běh kontrola-p5.sh s buildem (ne --bez-buildu), oddíly D a E bez CHYBA, test anonymního čtení PASS (oddíl F)
a tato kontrola vyplněná bez NE v A až E (oddíl G).
Vyplnit ji stačí před odevzdáním artefaktu P6 nebo P8. Kontrolu opakuj před každým nasazením a po každé větší změně dat. -->

Datum: [DOPLŇ] · Commit: [DOPLŇ hash] · Kdo kontroloval: [DOPLŇ role]

## A. Repo a tajemství

- [ ] **A1** `.env` není v gitu a je v `.gitignore`; `.env.example` v gitu je, jen s názvy. Jak ověřeno: `kontrola-p5.sh` oddíl C. → [DOPLŇ ANO/NE]
- [ ] **A2** gitleaks: celá historie bez nálezu; pre-commit hook z P1 je aktivní v tomto repu. → [DOPLŇ]
- [ ] **A3** Žádná tajná proměnná nemá prefix `NEXT_PUBLIC_` / `VITE_`; hodnoty serverových proměnných nejsou v klientském bundlu (`kontrola-p5.sh` oddíl D a E). → [DOPLŇ]
- [ ] **A4** Secret klíč čte jen serverový modul (`lib/supabase-server.ts` s `import 'server-only'`). → [DOPLŇ]
- [ ] **A5** Každý klíč je zapsaný v registru klíčů z P1 (soubor `rozpocet/klice-registr.md` v repu z P1, ne v repu appky: kde je, k čemu, kdo ho smí rotovat), bez hodnoty. → [DOPLŇ]

## B. Data a RLS

- [ ] **B1** Každá tabulka v exponovaném schématu má zapnuté RLS a odebraná práva `anon` a `authenticated` v migraci (ne klikáním); výchozí práva pro nové objekty odebraná (`0000_vychozi_prava.sql`). Ověřeno v běžící databázi, ne jen v souboru: v SQL Editoru `select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity;` vrátí prázdný výsledek (test anonymního čtení s kódem 42501 dokazuje jen odebraná práva, ne zapnuté RLS). → [DOPLŇ ANO + „dotaz vrátil 0 řádků“]
- [ ] **B2** `scripts/test-anonymniho-cteni.sh`: PASS u všech tabulek a pohledů, které Data API vystavuje (seznam bere z API, ne jen z migrací), tabulky přitom mají data. → [DOPLŇ čas běhu]
- [ ] **B3** Výjimky z „zakázat vše“: [DOPLŇ „žádné“, nebo seznam: tabulka, role, operace, podmínka, proč, test].
- [ ] **B4** Žádný pohled (view) ani funkce `security definer` v exponovaném schématu, nebo prošly revizí; funkce, které test vypsal jako POZOR, mají `execute` jen pro role, které je potřebují. → [DOPLŇ]
- [ ] **B5** Security Advisor v dashboardu Supabase bez nálezu typu `rls_disabled_in_public`, nebo nález vysvětlen. → [DOPLŇ]
- [ ] **B6** V aplikaci jsou jen demo data. Ostrá osobní data až po smlouvě o zpracování s poskytovatelem databáze a volbě regionu. → [DOPLŇ]

## C. Balíčky

- [ ] **C1** Každý balíček přidaný v P5 prošel `scripts/over-balicek.sh` a člověk ho schválil. Seznam: [DOPLŇ název, verdikt skriptu, proč OK]
- [ ] **C2** `package-lock.json` je v gitu; instalace v CI a na serveru přes `npm ci`. → [DOPLŇ]

## D. Testy a změny

- [ ] **D1** `npm test` zelené; žádný test není `.skip` ani `.only`. → [DOPLŇ]
- [ ] **D2** Do `main` vedly změny jen přes PR, diff četl člověk, agent nemá právo mergovat (deny `gh pr merge`, deny `mcp__*merge_pull_request*` a hook `strazce-p5.sh`; vím, že to je zábrana, ne zámek). GitHub MCP nebo plugin GitHubu je v tomto repu vypnutý, nebo na něj platí ten deny. → [DOPLŇ číslo PR]
- [ ] **D3** Kontrolní skripty, hooky a konfigurace testů (`scripts/`, `.githooks/`, `.gitleaks.toml`, `playwright.config.ts`) se od startu nezměnily, nebo změnu vysvětluji (`kontrola-p5.sh` oddíl C). → [DOPLŇ]

## E. Prostředí

- [ ] **E1** Vývoj a produkce jsou oddělené: jiný projekt Supabase, jiné klíče. V P5 produkce neexistuje. → [DOPLŇ]
- [ ] **E2** Agent (Claude Code, MCP) nemá přístupové údaje k produkci. Supabase MCP, pokud ho používám, jen s `project_ref` dev projektu, `read_only=true` (platí jen pro SQL dotazy) a `features=database,docs`; každé volání nástroje schvaluji ručně. Supabase CLI: vím, že po `supabase login` vidí agent přes Bash všechny projekty účtu. → [DOPLŇ]
- [ ] **E3** Nástroj nemá přihlášení, proto běží jen na mém počítači a v tomto stavu se nenasazuje (přihlášení řeší P6). → [DOPLŇ]
- [ ] **E4** Appka poslouchá jen na `127.0.0.1`: skript `dev` v `package.json` je `next dev -H 127.0.0.1` (bez `-H` poslouchá Next.js na 0.0.0.0 a appku otevře kdokoli ve stejné Wi-Fi; `kontrola-p5.sh` oddíl C). → [DOPLŇ]
- [ ] **E5** Claude Code v tomto repu nepracuje v auto mode (`defaultMode: acceptEdits`, `disableAutoMode` v `.claude/settings.json`; `kontrola-p5.sh` oddíl C). → [DOPLŇ]

## F. Incident a obnova

- [ ] **F1** Cvičení „unikl klíč“ hotové do 15 minut, starý klíč ověřeně neplatný (`docs/incident-cviceni.md`). → [DOPLŇ minuty]
- [ ] **F2** Vím, kde rotuji každý klíč (odkaz na stránku poskytovatele v registru klíčů) a kde vidím logy. → [DOPLŇ]
- [ ] **F3** Vím, kdy jde o porušení zabezpečení osobních údajů (GDPR čl. 4 bod 12): každý incident zapíšu do evidence (čl. 33 odst. 5); ÚOOÚ ohlašuji do 72 hodin, ledaže je nepravděpodobné, že by porušení mělo za následek riziko pro práva lidí (čl. 33 odst. 1); při vysokém riziku informuji i dotčené lidi (čl. 34). → [DOPLŇ]

## G. Prodej (jen pokud nástroj někomu prodávám)

- [ ] **G1** Nástroj jen interně používám, neprodávám: ANO / NE. Pokud prodávám, beru na vědomí směrnici o odpovědnosti za vadné výrobky (PLD, software je výrobek, výrobky po 9. 12. 2026) a nařízení CRA (hlášení od 11. 9. 2026), a nechám si to posoudit právníkem. → [DOPLŇ]

## Známá omezení (co vím, že není dobře, a kdy to opravím)

- [DOPLŇ nebo „žádná“]
