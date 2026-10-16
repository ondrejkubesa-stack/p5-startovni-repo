#!/usr/bin/env bash
# test-anonymniho-cteni.sh - bezpecnostni brana B6 (kurz darkondrej.ai, modul P5.2). v1.2
# Otazka: precte nebo zapise nekdo s VEREJNYM (publishable) klicem data z mych tabulek?
# Spoustis TY ve svem terminalu, v koreni repa (cte .env, proto ne pres Claude Code).
#
# Pouziti:  bash scripts/test-anonymniho-cteni.sh                 # tabulky a pohledy vezme z Data API + z migraci
#           bash scripts/test-anonymniho-cteni.sh poptavky dalsi  # nebo je vyjmenuj
#
# 0. KLICE: overi, ze publishable i secret klic jsou platne (GET /auth/v1/settings). Neplatny klic = test nebezi (exit 2),
#    jinak by odmitnuti 401 vypadalo jako ochrana.
# 1. SEZNAM: secret klicem stahne popis Data API (GET /rest/v1/) a vezme z nej vsechny vystavene tabulky a pohledy,
#    i ty naklikane v dashboardu. Funkce (rpc) vypise jako POZOR k rucni kontrole (nespousti je).
# Pro kazdou tabulku:
#   2. PREDPOKLAD: secret klicem zjisti POCET radku (data nestahuje). Prazdna tabulka = test nic nedokazuje = CHYBA.
#   3. CTENI publishable klicem. PASS jen pri kodu 42501 (opravneni) nebo HTTP 200 s prazdnym polem.
#   4. ZAPIS publishable klicem (prazdny radek). PASS jen pri kodu 42501. Cokoli jineho (2xx, chyba sloupce, 5xx, sit) = CHYBA.
#   5. ZMENA A SMAZANI publishable klicem (PATCH a DELETE s nesplnitelnym filtrem, nic se nezmeni ani nesmaze). PASS jen pri 42501.
# v1.2 (dorovnani z oponentury S8): pridan krok 5, dosud se zkousel jen select a insert.
# Nikdy nevypisuje hodnoty klicu ani obsah radku. Klice jdou do curl pres stdin (-H @-). Exit 0 = PASS, 1 = CHYBA, 2 = nebezel.
#
# Overeno k 2026-10-07 proti https://supabase.com/docs/guides/getting-started/api-keys, .../row-level-security
# a .../api/securing-your-api. VOLATILNI: format chyb PostgREST, pristup k popisu Data API, vychozi prava. Bash 3.2.

set -u
command -v curl >/dev/null 2>&1 || { echo "Chybi curl."; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "Chybi jq (macOS 15+: /usr/bin/jq, jinak brew install jq; Linux/WSL: sudo apt install jq)."; exit 2; }
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$ROOT" || exit 2
[ -f .env ] || [ -f .env.local ] || { echo "Nenasel jsem .env ani .env.local v $ROOT."; exit 2; }

env_hodnota() { # hodnota z .env.local, jinak z .env (poradi jako Next.js); soubor se NESPOUSTI, jen cte
  for f in .env.local .env; do
    [ -f "$f" ] || continue
    v="$(grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$f" | tail -n 1 | sed -E "s/^[[:space:]]*(export[[:space:]]+)?$1=//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]+$//")"
    [ -n "$v" ] && { printf '%s' "$v"; return; }
  done
}

URL="$(env_hodnota SUPABASE_URL)"; [ -n "$URL" ] || URL="$(env_hodnota NEXT_PUBLIC_SUPABASE_URL)"
PUB="$(env_hodnota SUPABASE_PUBLISHABLE_KEY)"; [ -n "$PUB" ] || PUB="$(env_hodnota NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)"
SEC="$(env_hodnota SUPABASE_SECRET_KEY)"
URL="${URL%/}"

[ -n "$URL" ] || { echo "V .env chybi SUPABASE_URL."; exit 2; }
[ -n "$PUB" ] || { echo "V .env chybi SUPABASE_PUBLISHABLE_KEY (Settings > API Keys > Publishable key)."; exit 2; }
[ -n "$SEC" ] || { echo "V .env chybi SUPABASE_SECRET_KEY."; exit 2; }
# Secret klic smi jen na endpoint projektu Supabase nebo na lokalni Supabase CLI. Jina adresa = klic by unikl.
printf '%s' "$URL" | grep -Eq '^(https://[a-z0-9-]+\.supabase\.co|http://(127\.0\.0\.1|localhost):[0-9]+)$' \
  || { echo "STOP: na tuto adresu secret klic neodeslu. SUPABASE_URL musi byt https://<projekt>.supabase.co, nebo http://127.0.0.1:<port> pro lokalni Supabase CLI."; exit 2; }

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t anon)"; trap 'rm -rf "$TMP"' EXIT
dotaz() { # dotaz KLIC VYSTUP [curl argumenty...] -> HTTP kod; klic jde pres stdin
  k="$1"; o="$2"; shift 2
  printf 'apikey: %s\n' "$k" | curl -s --max-time 20 -o "$o" -w '%{http_code}' -H @- "$@"
}

# 0. Platnost klicu
for jm in PUB SEC; do
  eval "k=\$$jm"
  KOD="$(dotaz "$k" /dev/null "$URL/auth/v1/settings")"
  case "$KOD" in
    200) ;;
    000) echo "Supabase neni dosazitelny (HTTP 000). Zkontroluj sit a SUPABASE_URL."; exit 2 ;;
    *) [ "$jm" = PUB ] && n="SUPABASE_PUBLISHABLE_KEY" || n="SUPABASE_SECRET_KEY"
       echo "$n je neplatny nebo patri jinemu projektu (HTTP $KOD). Test by jinak hlasil falesne OK. Oprav .env."; exit 2 ;;
  esac
done

# 1. Seznam tabulek a pohledu: Data API + migrace + argumenty
FUNKCE=""
if [ $# -ge 1 ]; then
  TABULKY="$*"
else
  KOD="$(dotaz "$SEC" "$TMP/openapi" "$URL/rest/v1/")"
  Z_API=""
  if [ "$KOD" = "200" ]; then
    Z_API="$(jq -r '.paths // {} | keys[] | select(. != "/" and (startswith("/rpc/") | not)) | ltrimstr("/")' "$TMP/openapi" 2>/dev/null | tr '\n' ' ')"
    FUNKCE="$(jq -r '.paths // {} | keys[] | select(startswith("/rpc/")) | ltrimstr("/rpc/")' "$TMP/openapi" 2>/dev/null | tr '\n' ' ')"
  else
    echo "POZOR: popis Data API nejde nacist (HTTP $KOD); beru tabulky jen z migraci. Tabulky naklikane v dashboardu vyjmenuj jako argumenty."
  fi
  Z_MIGRACI="$(cat supabase/migrations/*.sql 2>/dev/null | tr 'A-Z' 'a-z' \
    | grep -Eo 'create table (if not exists )?(public\.)?[a-z_][a-z0-9_]*' \
    | sed -E 's/create table (if not exists )?(public\.)?//' | tr '\n' ' ')"
  TABULKY="$(printf '%s\n' $Z_API $Z_MIGRACI | sort -u | tr '\n' ' ')"
fi
[ -n "$(printf '%s' "$TABULKY" | tr -d ' ')" ] || { echo "Nenasel jsem tabulky. Zadej je jako argumenty."; exit 2; }

CHYB=0
echo "# Test anonymniho cteni - $(date +%Y-%m-%d\ %H:%M) - projekt: $(printf '%s' "$URL" | sed -E 's|https://([^.]{0,6})[^.]*\.|https://\1…\.|')"
echo "Tabulky a pohledy: $TABULKY"
echo

for T in $TABULKY; do
  echo "## $T"

  # 2. Predpoklad: tabulka ma data (pocet z hlavicky Content-Range, telo se zahodi)
  printf 'apikey: %s\nPrefer: count=exact\n' "$SEC" | curl -s --max-time 20 -o /dev/null -D "$TMP/h" -H @- "$URL/rest/v1/$T?select=*&limit=1"
  POCET="$(tr -d '\r' < "$TMP/h" | grep -i '^content-range:' | sed -E 's|.*/||' | tr -d ' ')"
  case "$POCET" in
    ''|'*') echo "  [CHYBA] Secret klicem nejde zjistit pocet radku (tabulka neexistuje nebo spatna URL)."; CHYB=$((CHYB+1)); echo; continue ;;
    0) echo "  [CHYBA] Tabulka je prazdna. Test nad prazdnou tabulkou nic nedokazuje. Nahraj demo data (supabase/seed.sql)."; CHYB=$((CHYB+1)); echo; continue ;;
    *) echo "  [OK]    predpoklad: tabulka ma $POCET radku (zjisteno secret klicem)" ;;
  esac

  # 3. Cteni publishable klicem
  KOD="$(dotaz "$PUB" "$TMP/b" "$URL/rest/v1/$T?select=*&limit=5")"
  PG="$(jq -r 'if type == "object" then (.code // "") else "" end' "$TMP/b" 2>/dev/null)"
  if [ "$KOD" = "200" ]; then
    N="$(jq -r 'if type == "array" then length else -1 end' "$TMP/b" 2>/dev/null)"
    if [ "$N" = "0" ]; then
      echo "  [OK]    cteni: anonym dostal prazdny vysledek (RLS radky skryla)"
    else
      echo "  [CHYBA] cteni: anonym PRECETL ${N} radku. Zapni RLS a odeber prava: viz supabase/migrations/0001_poptavky_rls.sql"
      CHYB=$((CHYB+1))
    fi
  elif [ "$PG" = "42501" ]; then
    echo "  [OK]    cteni: zamitnuto opravnenim (HTTP $KOD, kod 42501)"
  else
    echo "  [CHYBA] cteni: necekana odpoved (HTTP $KOD${PG:+, kod $PG}). Neni to dukaz ochrany (sit, vypadek, jina chyba). Zkus znovu; trva-li to, ukaz vystup lektorovi."
    CHYB=$((CHYB+1))
  fi

  # 4. Zapis publishable klicem (prazdny radek; projde jen tehdy, kdyz ma anonym pravo vkladat)
  KOD="$(printf 'apikey: %s\nContent-Type: application/json\nPrefer: return=minimal\n' "$PUB" \
    | curl -s --max-time 20 -o "$TMP/b" -w '%{http_code}' -X POST -H @- -d '{}' "$URL/rest/v1/$T")"
  PG="$(jq -r 'if type == "object" then (.code // "") else "" end' "$TMP/b" 2>/dev/null)"
  case "$KOD" in
    2*) echo "  [CHYBA] zapis: anonym VLOZIL radek. Odeber pravo insert (revoke) a testovaci radek smaz v SQL Editoru."; CHYB=$((CHYB+1)) ;;
    *)
      if [ "$PG" = "42501" ]; then
        echo "  [OK]    zapis: zamitnuto opravnenim (HTTP $KOD, kod 42501)"
      else
        echo "  [CHYBA] zapis: zastavila ho jina chyba nez opravneni (HTTP $KOD${PG:+, kod $PG}), napr. povinny sloupec."
        echo "          To neni ochrana: RLS je nejspis vypnute (nebo politika pousti vse) a anonym ma grant."
        echo "          Oprava: alter table public.$T enable row level security; revoke all on table public.$T from anon, authenticated;"
        CHYB=$((CHYB+1))
      fi ;;
  esac

  # 5. Zmena a smazani publishable klicem: PATCH a DELETE s filtrem, ktery nikdo nesplni (sloupec zaroven is null a not.is.null),
  # takze se nikdy nic nezmeni ani nesmaze. Nazev sloupce se bere z jednoho radku (secret klicem, jen nazev, ne hodnota).
  KL="$(printf 'apikey: %s\n' "$SEC" | curl -s --max-time 20 -H @- "$URL/rest/v1/$T?select=*&limit=1" | jq -r 'if type == "array" and length > 0 then (.[0] | keys[0]) else "" end' 2>/dev/null)"
  if ! printf '%s' "$KL" | grep -Eq '^[a-z_][a-z0-9_]*$'; then
    echo "  [CHYBA] zmena a smazani: nepodarilo se bezpecne zjistit nazev sloupce pro filtr, test PATCH a DELETE neni mozne provest."
    CHYB=$((CHYB+1))
  else
    for M in PATCH DELETE; do
      KOD="$(printf 'apikey: %s\nContent-Type: application/json\nPrefer: return=minimal\n' "$PUB" \
        | curl -s --max-time 20 -o "$TMP/b" -w '%{http_code}' -X "$M" -H @- -d '{}' "$URL/rest/v1/$T?$KL=is.null&$KL=not.is.null")"
      PG="$(jq -r 'if type == "object" then (.code // "") else "" end' "$TMP/b" 2>/dev/null)"
      case "$KOD" in
        2*) echo "  [CHYBA] $M: anonym ma pravo ($KOD). Odeber pravo: revoke update, delete on table public.$T from anon, authenticated;"; CHYB=$((CHYB+1)) ;;
        *)
          if [ "$PG" = "42501" ]; then echo "  [OK]    $M: zamitnuto opravnenim (HTTP $KOD, kod 42501)"
          else echo "  [CHYBA] $M: zastavila ho jina chyba nez opravneni (HTTP $KOD${PG:+, kod $PG}); to neni ochrana."; CHYB=$((CHYB+1)); fi ;;
      esac
    done
  fi
  echo
done

if [ -n "$(printf '%s' "$FUNKCE" | tr -d ' ')" ]; then
  echo "POZOR: Data API vystavuje funkce (rpc): $FUNKCE"
  echo "       Test je nespousti. Over v predletove kontrole B4, ze execute maji jen role, ktere je potrebuji."
  echo
fi

if [ "$CHYB" -eq 0 ]; then
  echo "VYSLEDEK: PASS. Verejny klic tabulky neprecte, nezapise, nezmeni ani nesmaze. (B6 splneno)"; exit 0
else
  echo "VYSLEDEK: CHYBA ($CHYB). Do P6 a P8 s timto stavem nevstupuj."; exit 1
fi
