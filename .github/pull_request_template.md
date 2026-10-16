## Co se mění

Úkoly z `docs/tasks.md`: T…
Kritéria ze `docs/spec.md`: A…

## Jak to bylo ověřeno (vyplňuje agent)

- [ ] Červený test před implementací (výstup z T1 nebo hash commitu):
- [ ] `npm test` zelené (poslední řádek výstupu):
- [ ] `npm run build` projde
- [ ] Nové balíčky (název + výstup `scripts/over-balicek.sh`), nebo „žádné“:

## Čtení diffu (vyplňuje člověk, checklist P5.1)

- [ ] Prošel jsem každý změněný soubor, ne jen shrnutí.
- [ ] Testy nejsou oslabené (`.skip`, `.only`, změněná očekávaná hodnota, smazaný test).
- [ ] Žádný klíč, `.env`, osobní údaj, výpis celých záznamů do konzole.
- [ ] Žádná proměnná s klíčem s prefixem `NEXT_PUBLIC_` / `VITE_`.
- [ ] Změny v `.claude/`, `.github/`, `scripts/`, `.githooks/`, `.gitleaks.toml`, `playwright.config.ts`, `supabase/migrations/` a `package.json` mají vysvětlení (nebo žádné nejsou).
- [ ] Nic mimo rozsah spec (nové funkce „navíc“).

**Co jsem v diffu zpochybnil nebo změnil (aspoň jedna věta, i „nic, protože …“):**
