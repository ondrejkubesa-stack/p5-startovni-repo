# Záznam incidentu: cvičení „unikl klíč“

<!-- Šablona P5.2 · v1.2 · ověřeno k 2026-10-12 · vlastník OK. Postup: ~/kurz/sablony/P5/P5.2-cviceni-unik-klice.md
Do záznamu NIKDY nepiš hodnotu klíče. Stačí název a nejvýš 6 znaků za prefixem (doporučení Supabase). -->

- **Začátek (čas):** [DOPLŇ HH:MM]
- **Konec (čas):** [DOPLŇ HH:MM]
- **Varianta:** [DOPLŇ A (API klíč z P1.2, Dílna) / B (secret klíč dev projektu Supabase, po úkolu P5.2)]
- **Který klíč:** [DOPLŇ název, např. „cviceni-unik“, nejvýš 6 znaků za prefixem]
- **Kde unikl (scénář):** [DOPLŇ např. screenshot v komunitě, vložený do chatu, commit]
- **Kde se klíč používal:** [DOPLŇ soubor .env na mém počítači, nic jiného / seznam]

## Postup s časy

| Čas | Krok | Hotovo |
|---|---|---|
| [DOPLŇ] | 1. Zdroj úniku odstraněn (příspěvek smazán nebo skrytý) a v registru klíčů zjištěno, kde všude klíč je | [DOPLŇ] |
| [DOPLŇ] | 2. `bash scripts/over-zneplatneni.sh …` spuštěn, starý klíč ověřen jako platný (krok PŘED) | [DOPLŇ] |
| [DOPLŇ] | 3. Nový klíč vytvořen, vložen do `.env`, restart (B: `npm test` zelené) | [DOPLŇ] |
| [DOPLŇ] | 4. Starý klíč smazán (kontrola podle názvu) | [DOPLŇ] |
| [DOPLŇ] | 5. Enter ve skriptu: starý klíč neplatí, nový ano (krok PO) | [DOPLŇ vlož celý výstup skriptu] |
| [DOPLŇ] | 6. Logy: požadavky nebo spotřeba, které nejsou moje (čas, IP, user agent, tabulka) | [DOPLŇ co jsem viděl] |
| [DOPLŇ] | 7. Registr klíčů aktualizován (datum rotace, nový název klíče) | [DOPLŇ] |

## Vyhodnocení

- **Dotkl se únik osobních údajů?** [DOPLŇ ne, jen demo data / ano: co, kolik, od kdy]
- **Je to porušení zabezpečení podle GDPR?** [DOPLŇ ne, protože … / ano] Zapisuje se do evidence vždy (čl. 33 odst. 5).
- **Ohlásit ÚOOÚ do 72 h (čl. 33)?** [DOPLŇ ne, riziko pro lidi je nepravděpodobné, protože … / ano] **Informovat dotčené lidi (čl. 34, vysoké riziko)?** [DOPLŇ]
- **Co změním, aby se to neopakovalo:** [DOPLŇ jedna věta s konkrétním krokem]
- **Co mě zdrželo:** [DOPLŇ]
