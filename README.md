# p5-startovni-repo

Veřejné šablonové repo (Template repository) ke kurzu **AI pro podnikatele** na [darkondrej.cz](https://darkondrej.cz), dráha Pokročilí, modul **P5 Vibecoding bezpečně** (lekce P5.1 Od specifikace k appce a P5.2 Data, tajemství a předletová kontrola). Je to čerstvá aplikace Next.js s Playwrightem a se šablonami z modulů P1, P2 a P5 už sloučenými dohromady. Ušetří ti 30 až 45 minut ručního skládání a chyby z kopírování.

## Co v repu je

- Next.js 16.4.0 z `create-next-app` (TypeScript, App Router, `AGENTS.md`), bez zpětné vazby pro Next.js (`--no-agent-feedback`). Pravidla modulu P5 jsou připojená **pod** blok Next.js v `AGENTS.md`.
- Playwright (`@playwright/test`), konfigurace a první padající test `tests/poptavky.spec.ts`.
- `docs/spec.md` a `docs/tasks.md` (šablony zadání), `docs/predletova-kontrola.md`, `docs/incident-cviceni.md`.
- `.claude/settings.json` sloučený z modulů P2 a P5 (režim `acceptEdits`, zákazy, dva hooky `strazce.sh` a `strazce-p5.sh`).
- Gitleaks: hook `.githooks/pre-commit`, workflow `.github/workflows/gitleaks.yml`, pravidlo pro `sb_secret_` v `.gitleaks.toml`.
- Skripty `scripts/` (kontrola P5, prověrka balíčku, testy hooku, test anonymního čtení, důkaz zneplatnění klíče) a `supabase/` (migrace s RLS a demo data).
- `data/poptavky.demo.json`: vymyšlená demo data smyšlené firmy Truhlářství Dub.
- `scripts.dev` startuje na `127.0.0.1` (jen tvůj počítač), `scripts.test` spouští Playwright.

Balíčky pro Supabase (`@supabase/supabase-js`, `server-only`) v repu **nejsou**. Přidáš je v P5.2 až po prověrce `scripts/over-balicek.sh`.

## Jak to použít

Na GitHubu klikni **Use this template > Create a new repository** a nastav **Private**. Nebo v terminálu (slovo `--private` nevynechej, bez něj by tvoje repo bylo veřejné):

```sh
mkdir -p ~/kurz-cviceni && cd ~/kurz-cviceni
gh repo create evidence-poptavek --private --template ondrejkubesa-stack/p5-startovni-repo --clone
cd evidence-poptavek && npm install
npx playwright install --with-deps chromium   # Linux a WSL se zeptá na heslo sudo
sh scripts/instaluj-hook.sh && chmod +x .claude/hooks/*.sh scripts/*.sh
cp .env.example .env
```

Dál podle lekce P5.1 na darkondrej.cz. Repo zakládej mimo Plochu a Dokumenty (iCloud). Na Windows pracuj ve WSL v domovské složce.

## Pravidla

- `scripts/kontrola-p5.sh`, `scripts/test-anonymniho-cteni.sh` a `scripts/over-zneplatneni.sh` čtou `.env`. Spouštíš je **ty ve svém terminálu**, ne přes Claude Code.
- `.env` nikdy necommituj a neposílej do chatu. Skutečné klíče do šablony nepatří; všechna data jsou vymyšlená.
- `scripts/`, `.githooks/`, `.gitleaks.toml` a `playwright.config.ts` hlídají práci agenta. Bez tvého souhlasu je měnit nemá.

Verze nástrojů a názvy tlačítek se mění. Platí datum ověření v hlavičce lekce. Šablony P1, P2 a P5 byly ověřeny k 2026-10-16 s Next.js 16.4.0 a `create-playwright` 1.17.139.

## Licence

MIT, viz [LICENSE](LICENSE). Šablonu můžeš volně používat a upravovat pro svou firmu.
