# Úkoly: [DOPLŇ název nástroje]

<!-- Šablona P5.1 · v1.1 · ověřeno k 2026-10-07 · vlastník OK.
Pravidla: úkol = nejvýš 30 minut práce agenta a jeden commit. Každý úkol má ověření. První úkol je padající test.
Úkol, který nemá oporu v docs/spec.md, sem nepatří (škrtá člověk).
Commit každého úkolu začíná jeho ID („T1: …“). Skript kontrola-p5.sh podle commitu „T1:“ ověří, že se test od té doby nezměnil. -->

Větev: `feat/[DOPLŇ]`

- [ ] **T1 Padající test pro A1.** Ověření: `npm test` skončí s jedním neúspěšným testem a chyba je „prvek nenalezen“, ne překlep v testu. Výstup (aspoň poslední řádky se souhrnem) vlož do bloku níže:
  ```
  [DOPLŇ výstup červeného testu]
  ```
- [ ] **T2 [DOPLŇ]** Ověření: [DOPLŇ]
- [ ] **T3 [DOPLŇ]** Ověření: [DOPLŇ]
- [ ] **T4 Zelená.** Ověření: `npm test` je zelené, test se od T1 nezměnil (`git diff <hash commitu T1> -- tests/` nic nevypíše; hash najdeš přes `git log --oneline --grep "^T1:"`).
- [ ] **T5 PR.** Ověření: PR z větve do `main`, popis podle šablony, člověk přečetl diff a mergnul volbou „Create a merge commit“ (zachová commity po úkolech, ze kterých skript ověřuje T1).

Škrtnuto při revizi (proč):
- [DOPLŇ nebo „nic“]
