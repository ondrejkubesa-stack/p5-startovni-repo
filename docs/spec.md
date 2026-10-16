# Specifikace: [DOPLŇ název nástroje]

<!-- Šablona P5.1 · v1.1 · ověřeno k 2026-10-07 · vlastník OK.
Pravidla: jedna strana A4. Píše ji člověk (agent se ptá, člověk rozhoduje). Kód podle ní vzniká až po schválení.
Vzor vyplnění: ~/kurz/sablony/P5/priklad-spec-a-tasks-evidence-poptavek.md -->

## 1. Problém a cíl

- **Dnes:** [DOPLŇ jak se to dělá teď, kdo, kolik času týdně, co se ztrácí]
- **Cíl:** [DOPLŇ jedna věta, co bude jinak, až nástroj poběží]
- **Kdo nástroj používá:** [DOPLŇ role, ne jména; počet lidí]

## 2. Akceptační kritéria

Každé kritérium je ověřitelné testem nebo jedním ručním krokem. 3 až 7 kusů. Formát: „Když …, pak …“.

- **A1** [DOPLŇ hlavní scénář, ten bude první test]
- **A2** [DOPLŇ]
- **A3** [DOPLŇ]

## 3. Co nástroj NEDĚLÁ (v této verzi)

Aspoň dvě položky. Chrání před tím, aby agent „vylepšoval“.

- [DOPLŇ např. přihlášení, export, odesílání e-mailů, napojení na účetnictví]
- [DOPLŇ]

## 4. Data

- **Co se ukládá:** [DOPLŇ pole a typy]
- **Osobní údaje:** v kurzu jen demo data, žádná jména, telefony ani e-maily skutečných lidí. Ostrý provoz až po vyřešení smlouvy o zpracování a předletové kontrole.
- **Kde:** P5.1 soubor `data/poptavky.json` (v `.gitignore`, demo data v `data/poptavky.demo.json`); P5.2 dev projekt Supabase.

## 5. Obrazovky a ovládání

- [DOPLŇ co je na obrazovce, popisky polí přesně tak, jak je použije test]

## 6. Technické mantinely

- Stack: [DOPLŇ, referenční: Next.js + TypeScript, Playwright, od P5.2 Supabase]
- Běží jen na mém počítači na adrese `127.0.0.1` (skript `dev` je `next dev -H 127.0.0.1`), bez přihlášení. **Bez přihlášení se nikdy nenasazuje** (P6).
- Nové balíčky jen po `scripts/over-balicek.sh` a schválení člověkem.

## 7. Otevřené otázky

- [DOPLŇ co ještě nevím; agent se na to nesmí „domyslet“]
