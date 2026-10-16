@AGENTS.md

# Jen pro Claude Code

- Režim oprávnění v tomto repu: `acceptEdits`. Bez dotazu projdou úpravy souborů a příkazy `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp` a `sed` v pracovní složce; ostatní příkazy s dotazem. Úpravy `scripts/`, `.githooks/`, `.gitleaks.toml`, `playwright.config.ts` a `package.json` jsou v `.claude/settings.json` nastavené s dotazem. Auto mode je vypnutý (`disableAutoMode`). Do auto mode nepřepínej a nenavrhuj ho.
- Novou funkci začni v plan mode (`claude --permission-mode plan`, nebo `Shift+Tab`, dokud stavový řádek neukáže `⏸ plan mode on`). Soubory začneš psát až poté, co člověk plán schválí volbou „Yes, manually approve edits“ nebo „Yes, auto-accept edits“. V plan mode spouštěj jen příkazy, které čtou; nic nezapisuj ani neinstaluj přes shell, dokud plán není schválený.
- Mezi úkoly z `docs/tasks.md` člověk dává `/clear`. Kontext pro další úkol ber ze spec, tasks a gitu, ne z paměti konverzace.
- Když hook nebo `permissions.deny` akci zablokuje, nehledej obchvat (jiný zápis příkazu, `gh api`, `sh -c`). Napiš, co jsi chtěl udělat, a navrhni bezpečnou cestu.
- `scripts/kontrola-p5.sh`, `scripts/test-anonymniho-cteni.sh` a `scripts/over-zneplatneni.sh` čtou `.env`, proto je spouští člověk ve vlastním terminálu, ne ty (hook `strazce-p5.sh` je zablokuje). `scripts/over-balicek.sh` a `scripts/over-strazce-p5.sh` `.env` nečtou a spouštět je smíš.

<!-- Šablona P5 · v1.2 · ověřeno k 2026-10-12 · vlastník OK. Režimy oprávnění, plan mode a schválení plánu:
https://code.claude.com/docs/en/permission-modes (volatilní, Claude Code vychází 20–29× měsíčně, fakta C-20).
Import @AGENTS.md: viz P2 (AGENTS.md se bez importu nečte, když existuje CLAUDE.md). Pokud create-next-app vytvořil
vlastní CLAUDE.md, tento soubor ho nahradí; import @AGENTS.md zůstává. -->
