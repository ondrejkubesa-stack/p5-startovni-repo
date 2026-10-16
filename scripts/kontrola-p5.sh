#!/usr/bin/env bash
# kontrola-p5.sh - akceptacni skript modulu P5 (kurz darkondrej.ai, darkondrej.cz/klub). v1.4
# Spoustis TY, u sebe, v koreni repa, ve vlastnim terminalu (skript cte .env, proto ne pres Claude Code;
# hook strazce-p5.sh ho agentovi zakazuje):
#     bash scripts/kontrola-p5.sh              # vse vcetne npm run build
#     bash scripts/kontrola-p5.sh --bez-buildu # rychla kontrola; bundle pak oznaci RUCNE
# Vytvori kontrola-p5-zprava.md (v .gitignore), kterou odevzdas formularem.
# Nic neodesila, v repu nic nemeni (krome zpravy a vystupu buildu), nikdy nevypisuje hodnoty klicu.
#
# Oddily: A plan (spec, tasks) · B testy · C git a GitHub · D tajemstvi · E bundle · F RLS · G predletova kontrola a cviceni
# Na konci tri radky, podle kterych se rozhoduje (jinak jsou CHYBA doporuceni k oprave, ne zamitnuti):
#   Jadro P5.1 = oddil B: commit "T1:" nalezen, testy z nej nezmenene ani nesmazane, npm test zelene;
#                oddil A: pod T1 v tasks.md vlozeny vystup cerveneho testu (N failed)
#   Jadro P5.2 = oddil F: test anonymniho cteni PASS
#   Brana do P6 a P8 = plny beh s buildem (ne --bez-buildu), oddily D a E bez CHYBA, test anonymniho cteni PASS (F)
#                      a predletova kontrola vyplnena bez NE v oddilech A az E (G)
# Poctive limity: (1) skript lezi v repu, takze ho agent muze zmenit (s dotazem); zprava z upraveneho skriptu
# neplati, proto otisk skriptu ve zprave a zivy beh v klinice. (2) Skript spousti npm test a npm run build, tedy kod,
# ktery psal agent, v TVEM terminalu s pristupem k .env. Pred spustenim precti diff (checklist P5.1).
# (3) Oddil C overuje nastaveni a hook simulaci (scripts/over-strazce-p5.sh), ne ze hook v tve session opravdu bezi.
# Overeno k 2026-10-12 (verze nastroju volatilni, viz hlavicka lekce). VOLATILNI: nazvy slozek buildu,
# format gitleaks a gh. Kompatibilni s bash 3.2 (macOS), Linux a WSL (Windows jen pres WSL, repo v ~/, ne v /mnt/c).

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Spust skript uvnitr git repa."; exit 2; }
cd "$ROOT" || exit 2
BUILD=1; [ "${1:-}" = "--bez-buildu" ] && BUILD=0

ZPRAVA="kontrola-p5-zprava.md"
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t p5)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0; RUCNE=0; RADKY=""; J1_T1=0; J1_TEST=0; J1_RED=0; J2=0; PK_OK=0; FAIL_DE=0

zapis() { # zapis OK|CHYBA|RUCNE ODDIL "text"
  case "$1" in OK) PASS=$((PASS+1)); s="OK   " ;; CHYBA) FAIL=$((FAIL+1)); s="CHYBA"; case "$2" in D|E) FAIL_DE=$((FAIL_DE+1)) ;; esac ;; *) RUCNE=$((RUCNE+1)); s="RUCNE" ;; esac
  printf '[%s] %s  %s\n' "$s" "$2" "$3"
  RADKY="${RADKY}| $2 | $s | $3 |
"
}
najdi() { for f in "$@"; do [ -f "$f" ] && { echo "$f"; return; }; done; echo ""; }
pocet() { grep -Ec "$1" "$2" 2>/dev/null || true; }

# Vsechny env soubory, ktere Next.js nacita (.env.local ma prednost pred .env); kontroluji se oba.
ENVFILES=""; for f in .env.local .env; do [ -f "$f" ] && ENVFILES="$ENVFILES $f"; done
env_jmena() { for f in $ENVFILES; do grep -Eo '^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=' "$f" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?//; s/=$//'; done | sort -u; }
env_hodnoty() { for f in $ENVFILES; do grep -E "^[[:space:]]*(export[[:space:]]+)?$1=" "$f" | tail -n 1 | sed -E "s/^[[:space:]]*(export[[:space:]]+)?$1=//; s/^[\"']//; s/[\"'][[:space:]]*$//; s/[[:space:]]+$//"; done; }
# Verejne hodnoty, ktere v bundlu byt smi (adresa projektu, publishable/anon klic)
je_verejna() { case "$1" in *URL*|*PUBLISHABLE*|*ANON*|DATA_SOUBOR) return 0 ;; *) return 1 ;; esac; }

echo "== Kontrola P5 v $(basename "$ROOT") =="

# ---------- A. Plan ----------
SPEC="$(najdi docs/spec.md spec.md)"; TASKS="$(najdi docs/tasks.md tasks.md)"
if [ -z "$SPEC" ]; then zapis CHYBA A "Chybi docs/spec.md."
else
  if grep -q '\[DOPL' "$SPEC"; then zapis CHYBA A "$SPEC obsahuje nevyplnene znacky [DOPLN]."
  else zapis OK A "$SPEC vyplnena."; fi
  n="$(grep -Ec '(^|[^A-Za-z0-9])A[0-9]+([^0-9]|$)' "$SPEC")"
  [ "$n" -ge 3 ] && zapis OK A "Spec ma $n radku s akceptacnimi kriterii (A1, A2, ...)." || zapis CHYBA A "Spec ma mene nez 3 akceptacni kriteria s ID (A1, A2, A3)."
  grep -Eq '[Nn][Ee][Dd]([Ee]|ě|Ě)[Ll]([Aa]|á|Á)' "$SPEC" && zapis OK A "Spec ma oddil Co nastroj NEDELA." || zapis CHYBA A "Spec nema oddil Co nastroj NEDELA."
fi
if [ -z "$TASKS" ]; then zapis CHYBA A "Chybi docs/tasks.md."
else
  hotove="$(pocet '^[[:space:]]*- \[[xX]\]' "$TASKS")"; otevrene="$(pocet '^[[:space:]]*- \[ \]' "$TASKS")"
  grep -q '\[DOPL' "$TASKS" && zapis CHYBA A "$TASKS obsahuje nevyplnene znacky [DOPLN]." || zapis OK A "$TASKS: hotovo $hotove, otevreno $otevrene."
  # vystup cerveneho testu se hleda jen uvnitr bloku kodu (```) pod T1, ne v textu zadani
  cerveny="$(awk '/T1/ && !t1 {t1=1} t1 && /^[[:space:]]*- \[[ xX]\] \*\*T2/ {exit} t1 && /^[[:space:]]*```/ {b=!b; next} t1 && b {print}' "$TASKS" | grep -Ec '[0-9]+ failed' || true)"
  [ "${cerveny:-0}" -ge 1 ] && J1_RED=1
  [ "${cerveny:-0}" -ge 1 ] && zapis OK A "V tasks.md je pod T1 vlozeny vystup cerveneho testu (N failed)." || zapis CHYBA A "V tasks.md chybi pod T1 v bloku kodu vystup cerveneho testu (radek s 'N failed')."
fi

# ---------- B. Testy ----------
if [ ! -f package.json ]; then zapis CHYBA B "Chybi package.json."
elif ! grep -q '"test"[[:space:]]*:' package.json; then zapis CHYBA B "package.json nema skript \"test\" (napr. \"test\": \"playwright test\")."
else
  nt="$(find tests e2e -type f \( -name '*.spec.*' -o -name '*.test.*' \) 2>/dev/null | wc -l | tr -d ' ')"
  [ "$nt" -ge 1 ] && zapis OK B "Testovacich souboru: $nt." || zapis CHYBA B "Ve slozce tests/ neni zadny *.spec.* ani *.test.*."
  oslab="$(grep -rEl '(^|[^A-Za-z0-9_])(test|it|describe)\.(skip|only|fixme)\(' tests e2e 2>/dev/null | tr '\n' ' ')"
  [ -z "$oslab" ] && zapis OK B "Zadne .skip/.only/.fixme v testech." || zapis CHYBA B "Oslabene testy (.skip/.only/.fixme): $oslab"
  # Test z T1 se od cerveneho commitu nesmi zmenit (rubrika P5.1-c, jadro)
  # nejstarsi commit "T1:" v historii HEAD; jen kdyz tam neni (squash merge), hleda se ve vsech vetvich
  T1C="$(git log --format=%H --grep='^T1:' HEAD 2>/dev/null | tail -n 1)"
  [ -n "$T1C" ] || T1C="$(git log --all --format=%H --grep='^T1:' 2>/dev/null | tail -n 1)"
  if [ -z "$T1C" ]; then
    zapis CHYBA B "Nenasel jsem commit se zpravou zacinajici 'T1:' (cerveny test). Merge PR volbou 'Create a merge commit', ne squash."
  else
    # jen zmenene nebo smazane soubory z T1; nove pridane testy (hloubka, druha iterace) jsou v poradku
    zmeny="$(git diff --name-only --diff-filter=MD "$T1C" HEAD -- tests e2e 2>/dev/null | tr '\n' ' ')"
    if [ -z "$zmeny" ]; then J1_T1=1; zapis OK B "Testy z commitu T1 (${T1C%"${T1C#???????}"}) se nezmenily ani nezmizely (nove testy smi pribyt)."
    else zapis CHYBA B "Testy z commitu T1 se zmenily nebo zmizely: $zmeny(zachranny prompt 6, nebo zmenu vysvetli v PR a lektorovi)."; fi
  fi
  echo "   ... spoustim npm test (muze trvat minutu)"
  if npm test >"$TMP/test.log" 2>&1; then J1_TEST=1; zapis OK B "npm test zelene: $(grep -Eo '[0-9]+ passed' "$TMP/test.log" | tail -n 1)"
  else zapis CHYBA B "npm test selhal: $(grep -Eo '[0-9]+ (failed|passed)' "$TMP/test.log" | tr '\n' ' ') (cely vystup: npm test)"; fi
fi

# ---------- C. Git a GitHub ----------
sledovane="$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -Ev '\.env\.(example|sample|template)$' | tr '\n' ' ')"
[ -z "$sledovane" ] && zapis OK C "Zadny .env soubor neni v gitu." || zapis CHYBA C "V gitu je soubor s tajemstvim: $sledovane (odstran z gitu a klice ROTUJ)."
for f in $ENVFILES; do
  git check-ignore -q "$f" && zapis OK C "$f je v .gitignore." || zapis CHYBA C "$f NENI v .gitignore."
done
case "$ENVFILES" in *.env.local*.env*) zapis RUCNE C "Existuje .env.local i .env. Next.js dava prednost .env.local; nech jen jeden (.env), at appka i skripty ctou totez." ;; esac
if git ls-files --error-unmatch .env.example >/dev/null 2>&1; then
  zapis OK C ".env.example je v gitu."
  podezrele="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env.example | grep -E '=(.*(sb_secret_|sb_publishable_|sk-ant-|ghp_|github_pat_|eyJ[A-Za-z0-9_-]{20,})|["'"'"']?[A-Za-z0-9_+/-]{32,})' | sed -E 's/=.*//' | tr '\n' ' ')"
  [ -z "$podezrele" ] && zapis OK C ".env.example nema hodnoty, ktere vypadaji jako klice." || zapis CHYBA C ".env.example ma u techto promennych hodnotu jako klic: $podezrele"
else
  zapis CHYBA C ".env.example neni v gitu. Over: git check-ignore -v .env.example (sablona create-next-app muze mit .env*)."
fi
if [ -f .claude/settings.json ] && command -v jq >/dev/null 2>&1; then
  deny="$(jq -r '.permissions.deny // [] | .[]' .claude/settings.json 2>/dev/null)"
  printf '%s' "$deny" | grep -q 'gh pr merge' && zapis OK C "Agent nema mergovat PR (deny gh pr merge; zabrana, ne zamek)." || zapis CHYBA C "V .claude/settings.json chybi deny Bash(gh pr merge *) (doplnek P5)."
  printf '%s' "$deny" | grep -Eq 'git push.*main' && zapis OK C "Agent nema pushovat na main (z P2)." || zapis CHYBA C "V .claude/settings.json chybi deny push na main (P2)."
  { grep -q 'strazce-p5.sh' .claude/settings.json && [ -x .claude/hooks/strazce-p5.sh ]; } \
    && zapis OK C "Hook strazce-p5.sh je zaregistrovany a spustitelny (skript overuje registraci, ne ze hook v session opravdu bezi)." || zapis CHYBA C "Hook .claude/hooks/strazce-p5.sh chybi, neni spustitelny (chmod +x) nebo neni v settings.json (bash scripts/sluc-nastaveni-P5.sh)."
  jq -e '[.hooks.PreToolUse[]?.hooks[]? | select((.command // "") | test("strazce")) | .onFailure] | all(. == "block") and length > 0' .claude/settings.json >/dev/null 2>&1 \
    && zapis OK C "Hooky maji onFailure block (rozbity hook akci zastavi, Claude Code 2.1.295+)." || zapis RUCNE C "Hooky nemaji \"onFailure\": \"block\": kdyz hook selze, akci propusti (doplnek P5, P2)."
  jq -e '[.hooks.PreToolUse[]? | select(tostring | test("strazce-p5")) | .matcher // ""] | any(test("Monitor"))' .claude/settings.json >/dev/null 2>&1 \
    && zapis OK C "Hook strazce-p5.sh hlida Bash i Monitor (matcher Bash|Monitor)." || zapis CHYBA C "Hook strazce-p5.sh nema v matcheru Monitor: prikaz spusteny nastrojem Monitor hook obejde. Spust znovu bash scripts/sluc-nastaveni-P5.sh."
  jq -e '.disableAllHooks == true' .claude/settings.json >/dev/null 2>&1 && zapis CHYBA C ".claude/settings.json ma \"disableAllHooks\": true: zadny hook nebezi."
  if [ -f .claude/settings.local.json ]; then
    jq -e '(.hooks // {} | length > 0) or (.permissions.defaultMode // "" | length > 0) or (.disableAllHooks // false) or (.permissions.allow // [] | map(select(test("^(Bash|Edit|Write|mcp__[*])$|[(][*][)]$"))) | length > 0)' .claude/settings.local.json >/dev/null 2>&1 \
      && zapis CHYBA C ".claude/settings.local.json (git ho nevidi, ma prednost) nastavuje hooky, rezim, vypnuti hooku nebo plose allow. Projdi: jq . .claude/settings.local.json" \
      || zapis OK C ".claude/settings.local.json nemeni hooky, rezim ani plose allow."
  fi
  if [ -f scripts/over-strazce-p5.sh ] && [ -f .claude/hooks/strazce-p5.sh ]; then
    vysl="$(bash scripts/over-strazce-p5.sh 2>&1 | tail -n 1)"
    case "$vysl" in *"CHYBA 0"*) zapis OK C "Testy obchvatu hooku: $vysl (simulace vstupu, ne zivy beh)." ;;
      *) zapis CHYBA C "Testy obchvatu hooku: ${vysl:-nebezely}. Spust bash scripts/over-strazce-p5.sh a porovnej hook se sablonou." ;; esac
  else
    zapis CHYBA C "Chybi scripts/over-strazce-p5.sh nebo .claude/hooks/strazce-p5.sh (sablona P5)."
  fi
  printf '%s' "$deny" | grep -q 'merge_pull_request' && zapis OK C "Merge nastrojem MCP (GitHub MCP) zakazany." || zapis RUCNE C "Chybi deny mcp__*merge_pull_request*: s pripojenym GitHub MCP muze agent mergnout PR mimo Bash."
  rezim="$(jq -r '.permissions.defaultMode // "nenastaveno"' .claude/settings.json 2>/dev/null)"
  vyp="$(jq -r '.permissions.disableAutoMode // .disableAutoMode // ""' .claude/settings.json 2>/dev/null)"
  if [ "$vyp" = "disable" ] && [ "$rezim" != "auto" ] && [ "$rezim" != "bypassPermissions" ]; then zapis OK C "Auto mode je v repu vypnuty, vychozi rezim: $rezim."
  else zapis CHYBA C "V .claude/settings.json chybi permissions.disableAutoMode \"disable\" (a defaultMode acceptEdits). Bez toho schvaluje prikazy klasifikator misto tebe."; fi
else
  zapis CHYBA C "Chybi .claude/settings.json (P2) nebo jq."
fi
if [ -f package.json ] && command -v jq >/dev/null 2>&1; then
  dev="$(jq -r '.scripts.dev // ""' package.json 2>/dev/null)"
  case "$dev" in
    *next\ dev*) printf '%s' "$dev" | grep -Eq '(-H|--hostname)[[:space:]=]+(127\.0\.0\.1|localhost)' \
        && zapis OK C "Appka posloucha jen na 127.0.0.1 (scripts.dev: $dev)." \
        || zapis CHYBA C "scripts.dev je '$dev': next dev bez -H posloucha na 0.0.0.0 (cela Wi-Fi). Oprava: npm pkg set scripts.dev=\"next dev -H 127.0.0.1\"" ;;
    *) zapis RUCNE C "scripts.dev neni next dev ('$dev'). Over, ze dev server posloucha jen na 127.0.0.1." ;;
  esac
fi
# Soubory, ktere "overuji" jadro, se od commitu, ktery je pridal, nemaji menit (acceptEdits by je agent upravil bez dotazu).
# Porovnava se s prvnim commitem KAZDEHO souboru, ne s korenem repa: create-next-app ma vlastni pocatecni commit
# a soubory P5 pribyvaji az po nem.
if git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  ochrany=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    pc="$(git log --diff-filter=A --format=%H -- "$f" 2>/dev/null | tail -n 1)"
    [ -n "$pc" ] || continue
    git diff --quiet "$pc" -- "$f" 2>/dev/null || ochrany="$ochrany$f "
  done <<SOUBORY
$(git log --diff-filter=A --name-only --format= -- scripts .githooks .gitleaks.toml playwright.config.ts 2>/dev/null | sort -u)
SOUBORY
  [ -z "$ochrany" ] && zapis OK C "Kontrolni skripty, hooky a konfigurace testu se od commitu, ktery je pridal, nezmenily ani nezmizely." \
    || zapis CHYBA C "Od pridani se zmenily nebo zmizely: $ochrany(git log -p -- <soubor>; zmenu vysvetli lektorovi, jinak vrat)."
fi
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  n="$(gh pr list --state merged --limit 50 --json number --jq 'length' 2>/dev/null || echo 0)"
  [ "${n:-0}" -ge 1 ] && zapis OK C "Mergnutych PR: $n." || zapis CHYBA C "Zadny mergnuty PR. Prace ma jit pres vetev a PR."
else
  zapis RUCNE C "gh neni prihlasene; odkaz na mergnuty PR vloz do odevzdani."
fi

# ---------- D. Tajemstvi ----------
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks git --redact --no-banner . >"$TMP/gl.log" 2>&1; then zapis OK D "gitleaks: cela historie bez nalezu."
  else zapis CHYBA D "gitleaks nasel tajemstvi v historii ($(grep -c 'RuleID' "$TMP/gl.log") nalezu). Klic ROTUJ, pak teprve res historii."; fi
else
  zapis CHYBA D "gitleaks neni nainstalovany (P1)."
fi
nh="$(git log -p --all 2>/dev/null | grep -Ec 'sb_secret_[A-Za-z0-9_-]{16,}' || true)"
[ "${nh:-0}" -eq 0 ] && zapis OK D "Historie gitu neobsahuje sb_secret_." || zapis CHYBA D "Historie gitu obsahuje sb_secret_ ($nh radku). Klic ROTUJ."
ZDROJE="$(git ls-files | grep -Ev '^(node_modules|\.next|dist|build|out)/' | grep -Ev '(^|/)scripts/kontrola-p5\.sh$')"
# Tajna = obsahuje SECRET, SERVICE_ROLE, PRIVATE, PASSWORD, TOKEN nebo KEY; vyjimka PUBLISHABLE a ANON (verejne klice)
verejne_tajne="$( { printf '%s\n' "$ZDROJE" | while IFS= read -r f; do [ -f "$f" ] && grep -Eho '(NEXT_PUBLIC|VITE|PUBLIC|EXPO_PUBLIC)_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE|PASSWORD|TOKEN|KEY)[A-Z0-9_]*' "$f" 2>/dev/null; done; env_jmena | grep -E '^(NEXT_PUBLIC|VITE|PUBLIC|EXPO_PUBLIC)_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE|PASSWORD|TOKEN|KEY)'; } | grep -Ev 'PUBLISHABLE|ANON' | sort -u | tr '\n' ' ')"
[ -z "$(printf '%s' "$verejne_tajne" | tr -d ' ')" ] && zapis OK D "Zadna tajna promenna s verejnym prefixem (NEXT_PUBLIC_/VITE_)." || zapis CHYBA D "Tajna promenna s verejnym prefixem: $verejne_tajne"

# ---------- E. Bundle (co dostane prohlizec) ----------
if [ "$BUILD" -eq 1 ] && [ -f package.json ] && grep -q '"build"[[:space:]]*:' package.json; then
  echo "   ... spoustim npm run build"
  if npm run build >"$TMP/build.log" 2>&1; then zapis OK E "npm run build projde."
  else zapis CHYBA E "npm run build selhal (cast chyby: $(grep -iE 'error' "$TMP/build.log" | head -n 1 | cut -c1-120))."; fi
fi
DIRS=""; for d in .next/static dist build out; do [ -d "$d" ] && DIRS="$DIRS $d"; done
if [ -z "$DIRS" ]; then
  zapis RUCNE E "Nenasel jsem vystup buildu (.next/static, dist, build, out). Spust bez --bez-buildu."
else
  unik=""
  for jm in $(env_jmena); do
    case "$jm" in NEXT_PUBLIC_*|VITE_*|PUBLIC_*|EXPO_PUBLIC_*) continue ;; esac
    je_verejna "$jm" && continue
    while IFS= read -r h; do   # po radcich: bez deleni na slova a bez rozvijeni globu v hodnote
      [ "${#h}" -ge 12 ] || continue
      grep -rqF -- "$h" $DIRS 2>/dev/null && unik="$unik $jm"
    done <<HODNOTY
$(env_hodnoty "$jm")
HODNOTY
  done
  # Zname formaty klicu bez ohledu na .env (klic vlozeny primo do kodu nebo s verejnym prefixem)
  for vz in 'sb_secret_[A-Za-z0-9_-]{16,}' 'sk-ant-[A-Za-z0-9_-]{16,}' 'sk-or-[A-Za-z0-9_-]{16,}' 'sk-proj-[A-Za-z0-9_-]{16,}' 'ghp_[A-Za-z0-9]{20,}' 'github_pat_[A-Za-z0-9_]{20,}'; do
    grep -rqE -- "$vz" $DIRS 2>/dev/null && unik="$unik ${vz%%[[]*}*"
  done
  [ -z "$unik" ] && zapis OK E "Hodnoty serverovych promennych v klientskem bundlu nejsou ($DIRS)." || zapis CHYBA E "V klientskem bundlu je hodnota:$unik. Klic ROTUJ a oprav kod."
fi

# ---------- F. RLS ----------
MIGR="$(ls supabase/migrations/*.sql 2>/dev/null | tr '\n' ' ')"
if [ -z "$MIGR" ]; then
  zapis RUCNE F "Zadne migrace v supabase/migrations/. Pokud appka nema databazi Supabase, popis v predletove kontrole, kde data jsou."
else
  tab="$(cat $MIGR | tr 'A-Z' 'a-z' | grep -Eo 'create table (if not exists )?(public\.)?[a-z_][a-z0-9_]*' | sed -E 's/create table (if not exists )?(public\.)?//' | sort -u)"
  for t in $tab; do
    cat $MIGR | tr 'A-Z' 'a-z' | grep -Eq "alter table (if exists )?(only )?(public\.)?$t enable row level security" \
      && zapis OK F "Tabulka $t ma v migraci zapnute RLS." || zapis CHYBA F "Tabulka $t nema v migraci enable row level security."
  done
  if [ -f scripts/test-anonymniho-cteni.sh ]; then
    bash scripts/test-anonymniho-cteni.sh >"$TMP/rls.log" 2>&1; rc=$?
    case "$rc" in
      0) J2=1; zapis OK F "Test anonymniho cteni: PASS (anonym neprecte ani nezapise, tabulky maji data)." ;;
      1) zapis CHYBA F "Test anonymniho cteni: CHYBA. Spust bash scripts/test-anonymniho-cteni.sh a oprav." ;;
      *) zapis CHYBA F "Test anonymniho cteni nebezel: $(tail -n 1 "$TMP/rls.log")" ;;
    esac
  else
    zapis CHYBA F "Chybi scripts/test-anonymniho-cteni.sh."
  fi
  # PASS s kodem 42501 dokazuje odebrana prava, ne zapnute RLS v bezici databazi (migrace na disku nemusi byt spustena)
  zapis RUCNE F "RLS v databazi: v SQL Editoru spust dotaz z docs/predletova-kontrola.md (B1, tabulky v public bez relrowsecurity); vysledek musi byt prazdny, vloz ho do B1."
fi

# ---------- G. Predletova kontrola a cviceni ----------
PK="$(najdi docs/predletova-kontrola.md predletova-kontrola.md)"
if [ -z "$PK" ]; then zapis CHYBA G "Chybi docs/predletova-kontrola.md."
else
  ot="$(pocet '^[[:space:]]*- \[ \]' "$PK")"
  if grep -q '\[DOPL' "$PK"; then zapis CHYBA G "$PK obsahuje nevyplnene znacky [DOPLN]."
  elif [ "$ot" -gt 0 ]; then zapis CHYBA G "$PK ma $ot nezaskrtnutych polozek (kazda: ANO, nebo NE s vysvetlenim a zaskrtnout)."
  else
    # V oddilech A az E je NE stop (brana neprojde); N/A schvaluje lektor. NE s vysvetlenim smi jen F a G.
    ne="$(grep -E '^[[:space:]]*- \[[xX]\] \*\*[A-E][0-9]+\*\*' "$PK" | grep -E '→[[:space:]]*(NE|Ne|ne)([^[:alnum:]]|$)' | grep -Eo '\*\*[A-E][0-9]+\*\*' | tr -d '*' | tr '\n' ' ' | sed 's/ $//')"
    na="$(grep -E '^[[:space:]]*- \[[xX]\] \*\*[A-E][0-9]+\*\*' "$PK" | grep -E '→[[:space:]]*N/?A([^[:alnum:]]|$)' | grep -Eo '\*\*[A-E][0-9]+\*\*' | tr -d '*' | tr '\n' ' ' | sed 's/ $//')"
    if [ -n "$ne" ]; then zapis CHYBA G "Predletova kontrola: NE u $ne. V oddilech A az E je NE stop: oprav a zmen na ANO, jinak brana neprojde."
    else PK_OK=1; zapis OK G "Predletova kontrola vyplnena, v oddilech A az E bez NE."; fi
    [ -n "$na" ] && zapis RUCNE G "Predletova kontrola: N/A u $na. Schvaluje lektor."
  fi
fi
IC="$(najdi docs/incident-cviceni.md incident-cviceni.md)"
if [ -z "$IC" ]; then zapis RUCNE G "Chybi docs/incident-cviceni.md (zaznam cviceni unikl klic, hloubka)."
else
  zac="$(grep -E '[Zz][Aa]([Cc]|č|Č)([Aa]|á|Á)[Tt][Ee][Kk]' "$IC" | grep -Eo '[0-9]{1,2}:[0-9]{2}' | head -n 1)"
  kon="$(grep -E '[Kk][Oo][Nn][Ee][Cc]' "$IC" | grep -Eo '[0-9]{1,2}:[0-9]{2}' | head -n 1)"
  if [ -n "$zac" ] && [ -n "$kon" ]; then
    m=$(( (10#${kon%%:*} * 60 + 10#${kon##*:}) - (10#${zac%%:*} * 60 + 10#${zac##*:}) ))
    [ "$m" -ge 0 ] && [ "$m" -le 15 ] && zapis OK G "Cviceni unikl klic: $m min (limit 15)." || zapis RUCNE G "Cviceni unikl klic: $m min. Nad 15 min: zapis, co zdrzelo, a zkus znovu."
  else
    zapis RUCNE G "V $IC chybi cas Zacatek a Konec (HH:MM) (zaznam cviceni je hloubka)."
  fi
  grep -q '\[DOPL' "$IC" && zapis RUCNE G "$IC obsahuje nevyplnene znacky [DOPLN] (zaznam cviceni je hloubka, lektor posoudi)."
  # presny radek z vystupu over-zneplatneni.sh, bez -i (jinak sedi i "ok" uvnitr slova v sablone)
  grep -Fq 'stary klic je neplatny (HTTP 401)' "$IC" && grep -Fq 'novy klic funguje' "$IC" \
    && zapis OK G "Neplatnost stareho klice dolozena vystupem over-zneplatneni.sh." || zapis RUCNE G "Vloz do $IC cely vystup scripts/over-zneplatneni.sh (radky 'stary klic je neplatny (HTTP 401)' a 'novy klic funguje')."
fi

# ---------- Rozhodnuti ----------
[ "$J1_T1" -eq 1 ] && [ "$J1_TEST" -eq 1 ] && [ "$J1_RED" -eq 1 ] && JADRO1="SPLNENO" || JADRO1="NESPLNENO"
[ "$J2" -eq 1 ] && JADRO2="SPLNENO" || JADRO2="NESPLNENO"
[ "$J2" -eq 1 ] && [ "$PK_OK" -eq 1 ] && [ "$BUILD" -eq 1 ] && [ "$FAIL_DE" -eq 0 ] && BRANA="SPLNENA" || BRANA="NESPLNENA"
[ "$BUILD" -eq 0 ] && BRANA="$BRANA (beh --bez-buildu branu nesplni, spust bez prepinace)"
# Otisk kontrolnich skriptu: lektor ho porovna s hodnotou na strance modulu (zmeneny skript = zprava neplati)
OTISK="$(for f in scripts/kontrola-p5.sh scripts/test-anonymniho-cteni.sh .claude/hooks/strazce-p5.sh scripts/over-strazce-p5.sh; do [ -f "$f" ] && printf '%s %s; ' "$f" "$(git hash-object "$f" | cut -c1-12)"; done)"

# ---------- Zprava ----------
{
  echo "# Kontrola P5 - $(date +%Y-%m-%d) - repo $(basename "$ROOT")"
  echo
  echo "Vysledek: **OK $PASS · CHYBA $FAIL · RUCNE $RUCNE**. Zprava neobsahuje hodnoty klicu ani data."
  echo
  echo "- **Jadro P5.1** (oddil B, test z T1 beze zmeny a zelene; oddil A, vystup cerveneho testu pod T1): **$JADRO1**"
  echo "- **Jadro P5.2** (oddil F, test anonymniho cteni PASS): **$JADRO2**"
  echo "- **Brana do P6 a P8** (plny beh s buildem, D a E bez CHYBA, F PASS, predletova kontrola v G bez NE v A az E): **$BRANA**"
  echo "- Otisk skriptu: $OTISK"
  echo
  echo "| Oddil | Stav | Zjisteni |"
  echo "|---|---|---|"
  printf '%s' "$RADKY"
  echo
  echo "Oddily: A plan · B testy · C git a GitHub · D tajemstvi · E bundle · F RLS · G predletova kontrola a cviceni."
  echo "Prijeti artefaktu rozhoduje jadro lekce (radky nahore). Ostatni CHYBA jsou doporuceni k oprave (hloubka), RUCNE posoudi lektor."
  echo "Do P6 a P8 se vstupuje jen se splnenou branou. Zpravu muze lektor v klinice overit zivym behem skriptu."
} > "$ZPRAVA"

echo
echo "Jadro P5.1: $JADRO1 · Jadro P5.2: $JADRO2 · Brana do P6 a P8: $BRANA"
echo "OK $PASS · CHYBA $FAIL · RUCNE $RUCNE  ->  $ZPRAVA (odevzdej formularem, necommituj)"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
