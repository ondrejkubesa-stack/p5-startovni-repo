#!/usr/bin/env bash
# strazce.sh - PreToolUse hook pro Claude Code (kurz darkondrej.ai, modul P2).
#
# Verze v1.5 (2026-10-12). Matcher: Bash, Monitor (spousti prikaz jako Bash, tool_input.command),
# Read, Edit, Write, NotebookEdit, Grep, Glob. Co blokuje:
#   1. cteni a upravy souboru s tajemstvim (.env, .env.*, ~/.ssh, ~/.aws, ~/.config/gh, ~/.git-credentials,
#      ~/.netrc, slozka secrets/) - krome .env.example/.sample/.template, i pres nastroje Grep a Glob.
#      Cesta se pred porovnanim normalizuje: ~, relativni cesta, ./ a ../, symlinky, mala pismena
#      (macOS nerozlisuje .ENV a .env).
#   2. Bash prikazy, ve kterych je nazev .env, cesta k SSH/AWS/gh udajum nebo secrets/ (i pres python -c,
#      cat, cp, glob .e*, maskovani .e"n"v), a prikazy, ktere prihlasovaci udaj VYPISI:
#      gh auth token, gh auth status --show-token/-t, aws configure get|export-credentials,
#      aws sts get-session-token, git credential fill, security find-*-password (Klicenka macOS),
#      gcloud auth print-*-token, az account get-access-token, promenne GH_TOKEN/GITHUB_TOKEN/AWS_*.
#   3. vlastni zamek: .claude/settings*.json a .claude/hooks/ (v projektu i v ~/.claude) upravuje jen clovek.
#      Edit/Write: podle normalizovane cesty. Bash: DENY-BY-DEFAULT - prikaz, ktery zmini slozku .claude
#      (i jako glob .cl*, i po "cd .claude") spolu se settings/hooks nebo mimo podslozky skills/agents/
#      commands/worktrees, projde jen tehdy, kdyz je cely jen pro cteni (cat, head, tail, ls, wc, stat,
#      diff, grep, jq, cd, pwd, git status|diff|log|show) bez presmerovani a bez $(...).
#   4. rekurzivni mazani (rm -r, -rf, -fr, -R, --recursive, i /bin/rm a bash -c '...')
#   5. git push z vetve main/master/production; push, jehoz CIL (za ":" nebo "+") konci na
#      /main, /master, /production (HEAD:main, HEAD:heads/main, @:refs/heads/main); push --all/--mirror;
#      force push; slouceni PR prikazem gh pr merge (na main byva navazane nasazeni).
#      Holou vetev feature/main (bez ":cil") pousti.
#   6. pracovni slozka (pole cwd ze vstupu, normalizovane jako cesty): v ~/.ssh, ~/.aws, ~/.config/gh
#      a secrets/ projde jen cd/pwd; uvnitr .claude (mimo skills/agents/commands/worktrees) jen cteni
#      (allowlist z bodu 3), protoze relativni "echo x > settings.json" nazev .claude neobsahuje;
#      z podslozky skills/... jen cteni, kdyz prikaz muze vylezt nahoru (.., cd -, popd, cd $X).
#      Grep/Glob bez path hledaji v cwd, kontroluje se tedy cwd.
#   7. promenna nebo substituce ($X, ${X}, $(...), `...`) je pro hook nevyhodnotitelna: spolu s chranenym
#      jmenem nebo jeho kusem (.en, .ss, .aw, secret, credential, .cl, settings, hooks) blokuje;
#      u tajemstvi vzdy, u zamku mimo cteni. Falesne poplachy (echo $HOME/.claude/skills) zamerne.
#
# Co NECHYTA (overeno simulaci 2026-10-12, radky [DIRA] v scripts/over-p2.sh, lekce P2.1 "Co nechrani ani hook"):
#   - prikaz, ve kterem nazev souboru nestoji ani jako vzor: grep -r TOKEN . ; tar czf x.tgz .
#   - nazev slozeny z kusu bez chraneneho jmena (a=.e; cat ${a}nv) nebo zakodovany (printf '\x2eenv'),
#     nazev ulozeny v promenne z drivejsiho prikazu, symlink zalozeny drive (ln -s .claude c; ... c/settings.json)
#   - cwd hook zna jen pred prikazem: cd uvnitr prikazu meni slozku az za behu (cd .claude && ... se chyta
#     jen podle textu .claude, cd do slozky pres symlink nebo promennou ne)
#   - PowerShell (nativni Windows) neni v matcheru; sablona pocita s bash v macOS/Linux/WSL
#   - program nebo skript, ktery soubor otevre sam: python3 uprav.py, node -e "...process.env...",
#     npm run dev s ladicim vypisem, git apply / tar x / unzip, ktere prepisou .claude/ zevnitr archivu
#   - vypis celeho prostredi (env, printenv, set), credential helpery jinych nastroju, alias gitu
#     (git -c alias.p=push p origin main), gh api .../merge, web GitHubu
#   - odchod dat ven (curl na cizi server) a nastroje MCP serveru (nejsou v matcheru)
#   - git clean -fdx (smaze i .env), find ... -delete
# Regularni vyraz nad textem prikazu NENI sandbox: kdo chce obejit, obejde. Skutecna ochrana:
#   - tajemstvi: testovaci ucet nebo token s minimalnim opravnenim, mimo repo, rotace po uniku;
#     sandbox.credentials a filesystem.denyRead (P2-1-osobni-sandbox.json) - vynucuje OS i pro skripty
#   - zamek: sandbox sam drzi .claude/settings*, .claude/hooks a ~/.claude jen pro cteni; mimo sandbox
#     zamceni na urovni OS, ktere bez hesla spravce nejde vratit: macOS sudo chflags schg (uchg nestaci,
#     ten vlastnik sunda bez hesla), Linux/WSL sudo chattr +i - na settings.json, settings.local.json
#     (predem zalozeny, jinak si ho agent vytvori s disableAllHooks) a strazce.sh; ve firme managed
#     settings s allowManagedHooksOnly (bezi jen hooky od spravce)
#   - push a merge: ochrana vetve na GitHubu ("Do not allow bypassing") a token gh s minimalnim opravnenim
#
# Pri chybe (chybejici +x, spatna cesta, vyprseny timeout, nativni Windows) hook ve vychozim stavu
# PROPOUSTI. Sablona ho proto registruje s "onFailure": "block" (Claude Code 2.1.295 a novejsi,
# Hooks reference, overeno 2026-10-12, volatilni): rozbity hook pak akci zastavi. Starsi verze pole
# ignoruji a propousteji dal. Chybejici jq nebo neplatny JSON na vstupu blokuje vzdy (exit 2).
# Log blokaci lezi v repu (.claude/hooks/blokace.log): je to zpetna vazba pro cloveka, ne dukaz odolny
# proti padelku - agentovi ho hook zapisovat nedovoli, clovek ano.
#
# Vstup: JSON na stdin (tool_name, tool_input, session_id, cwd). Vystup pri blokaci: JSON s
# permissionDecision "deny" + radek do .claude/hooks/blokace.log. Jinak nic = bezny tok opravneni.
# Duvody bez diakritiky zamerne (spolehlive kodovani v terminalu i JSON). Bash 3.2 (macOS) az 5.x.
#
# Overeno k 2026-10-12 proti https://code.claude.com/docs/en/hooks (Claude Code 2.1.280 lokalne,
# aktualni 2.1.296). VOLATILNI: schema hooku se meni, pri cervene kotve watcheru znovu otestovat
# skriptem scripts/over-p2.sh. Pole cwd: Hooks reference, "Common input fields" (sleduje cd i worktree).
# Monitor: Tools reference, "Monitor tool" (stejna pravidla opravneni jako Bash, prikaz v poli command,
# varianta ws bez prikazu); Hooks reference Monitor mezi priklady matcheru neuvadi - VOLATILNI.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "strazce.sh: chybi jq (macOS: je v /usr/bin/jq od macOS 15, jinak brew install jq; Linux/WSL: sudo apt install jq)" >&2
  exit 2   # radsi zablokovat nez pustit bez kontroly
fi

input="$(cat)"
tool="$(jq -r '.tool_name // ""' <<<"$input" 2>/dev/null)" \
  || { echo "strazce.sh: vstup neni platny JSON, blokuji" >&2; exit 2; }
session="$(jq -r '.session_id // "?"' <<<"$input")"
projekt="${CLAUDE_PROJECT_DIR:-$(pwd)}"
zakladna="$(jq -r '.cwd // ""' <<<"$input")"
[ -n "$zakladna" ] || zakladna="$projekt"
log="$projekt/.claude/hooks/blokace.log"

deny() {
  local duvod="$1"
  mkdir -p "$(dirname "$log")" 2>/dev/null
  printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$session" "$tool" "$duvod" >>"$log" 2>/dev/null
  jq -n --arg r "$duvod" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

male() { tr '[:upper:]' '[:lower:]' <<<"$1"; }   # macOS (APFS) nerozlisuje velikost pismen

# normalizuj CESTA -> absolutni cesta bez ~, ./, ../ a symlinku, malymi pismeny.
# Funguje i pro soubor, ktery jeste neexistuje (Write): existujici cast resi "cd -P", zbytek se slozi rucne.
normalizuj() {
  local p="$1" dir rest="" cast out cil i
  case "$p" in
    "~") p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
    /*) ;;
    *) p="$zakladna/$p" ;;
  esac
  for i in 1 2 3 4 5 6 7 8; do   # soubor je symlink (i retez): sledovat cil, max. 8 kroku
    [ -L "$p" ] || break
    cil="$(readlink -- "$p")"
    case "$cil" in /*) p="$cil" ;; *) p="$(dirname -- "$p")/$cil" ;; esac
  done
  dir="$p"
  while [ ! -d "$dir" ]; do
    rest="/$(basename -- "$dir")$rest"
    dir="$(dirname -- "$dir")"
  done
  out="$(cd -P -- "$dir" 2>/dev/null && pwd -P)" || out="$dir"
  set -f
  local IFS=/
  for cast in $rest; do
    case "$cast" in
      "" | .) ;;
      ..) out="$(dirname -- "$out")" ;;
      *) out="${out%/}/$cast" ;;
    esac
  done
  set +f
  male "$out"
}

je_tajny_soubor() { # $1 = cesta k souboru
  local n b
  n="$(normalizuj "$1")"
  b="${n##*/}"
  case "$b" in
    .env.example | .env.sample | .env.template) return 1 ;;
    .env | .env.* | .git-credentials | .netrc) return 0 ;;
  esac
  case "$n" in
    */.ssh | */.ssh/* | */.aws | */.aws/* | */.config/gh | */.config/gh/*) return 0 ;;
    */secrets | */secrets/*) return 0 ;;
  esac
  return 1
}

# zona_cwd -> "tajne" | "zamek" | "podslozka" | "" podle normalizovane pracovni slozky (pole cwd).
# O zone uvnitr .claude rozhoduje POSLEDNI .claude v ceste (worktree ma vlastni .claude).
zona_cwd() {
  local n po
  n="$(normalizuj "$zakladna")"
  case "$n" in
    */.ssh | */.ssh/* | */.aws | */.aws/* | */.config/gh | */.config/gh/* | */secrets | */secrets/*)
      echo tajne; return ;;
  esac
  case "$n" in */.claude | */.claude/*) ;; *) return ;; esac
  po="${n##*/.claude}"
  case "$po" in
    /skills | /skills/* | /agents | /agents/* | /commands | /commands/* | /worktrees | /worktrees/*) echo podslozka ;;
    "" | /*) echo zamek ;;
  esac
}

je_zamek() { # $1 = cesta; nastaveni a hooky Claude Code v jakekoli slozce (projekt, podslozka, ~/.claude)
  case "$(normalizuj "$1")" in
    */.claude/settings*.json | */.claude/hooks | */.claude/hooks/*) return 0 ;;
  esac
  return 1
}

# zminuje_claude PRIKAZ (male, bez uvozovek) -> 0, kdyz prikaz miri do .claude mimo povolene podslozky
zminuje_claude() {
  local c="$1" slova slovo cast dalsi i
  local -a casti
  # a) .claude spolu se slovem settings/hooks kdekoli v prikazu (i "cd .claude && ... settings.json")
  if grep -Eq '\.claude' <<<"$c" && grep -Eq 'settings|hooks' <<<"$c"; then return 0; fi
  # b) slovo, jehoz cast cesty je .claude (doslova nebo glob .cl*, .c?aude, .*)
  slova="$(tr ';&|()<>=:,{}`$' '               ' <<<"$c")"
  set -f
  for slovo in $slova; do
    IFS=/ read -r -a casti <<<"$slovo"
    i=0
    while [ "$i" -lt "${#casti[@]}" ]; do
      cast="${casti[$i]}"
      i=$((i + 1))
      case "$cast" in .*) ;; *) continue ;; esac   # glob bez tecky na zacatku .claude nerozbali
      # shellcheck disable=SC2053  # zamerne: $cast je vzor
      [[ .claude == $cast ]] || continue
      dalsi="${casti[$i]:-}"
      # povolena je jen doslovna cesta .claude/skills|agents|commands|worktrees bez .., bez cd a promennych
      if [ "$cast" = .claude ] && [[ "$slovo" != *..* ]] \
         && grep -Eqx 'skills|agents|commands|worktrees' <<<"$dalsi" \
         && ! grep -Eq '(^|[^[:alnum:]_])(cd|pushd)([[:space:]]|$)|[$`]' <<<"$c"; then
        continue
      fi
      set +f; return 0
    done
  done
  set +f
  return 1
}

# jen_cteni PRIKAZ -> 0, kdyz je kazda cast prikazu jen pro cteni (allowlist), bez presmerovani a substituce
jen_cteni() {
  local c seg prvni
  c="$(sed -E 's/[0-9]*>>?[[:space:]]*\/dev\/null//g; s/[0-9]*>&[0-9]//g' <<<"$1")"
  grep -Eq '[<>`]|\$\(' <<<"$c" && return 1
  grep -Eq -- '--output|--ext-diff|--textconv' <<<"$c" && return 1
  while IFS= read -r seg; do
    seg="${seg#"${seg%%[![:space:]]*}"}"
    [ -n "$seg" ] || continue
    prvni="${seg%%[[:space:]]*}"
    case "$prvni" in
      cat | head | tail | ls | wc | stat | diff | grep | jq | cd | pwd) ;;
      git) grep -Eq '^git[[:space:]]+(status|diff|log|show)([[:space:]]|$)' <<<"$seg" || return 1 ;;
      *) return 1 ;;
    esac
  done < <(tr ';&|' '\n\n\n' <<<"$c")
  return 0
}

case "$tool" in
  Grep | Glob)
    cesta="$(jq -r '.tool_input.path // "."' <<<"$input")"   # bez path hleda v pracovni slozce (cwd)
    filtr="$(male "$(jq -r '.tool_input.glob // ""' <<<"$input")")"   # jen Grep: filtr souboru
    if je_tajny_soubor "$cesta"; then
      deny "Strazce P2: hledani v souboru s tajemstvim ($cesta)."
    fi
    if grep -Eq '(^|[/*{,])\.env([*.}]|$)' <<<"$filtr" && ! grep -Eq '\.env\.(example|sample|template)' <<<"$filtr"; then
      deny "Strazce P2: hledani v souborech .env."
    fi
    ;;

  Read | Edit | Write | NotebookEdit)
    cesta="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")"
    if je_tajny_soubor "$cesta"; then
      deny "Strazce P2: soubor s tajemstvim ($cesta). Hodnoty klicu zadava clovek, agent pracuje s .env.example."
    fi
    if [ "$tool" != "Read" ] && je_zamek "$cesta"; then
      deny "Strazce P2: nastaveni a hooky (zamek) upravuje jen clovek, rucne a s commitem."
    fi
    ;;

  Bash | Monitor)   # Monitor spousti prikaz v tool_input.command stejne jako Bash (WebSocket varianta prikaz nema)
    cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
    nizky="$(male "$cmd")"
    # holy = bez uvozovek a zpetnych lomitek (.e"n"v -> .env, r'm' -> rm), malymi pismeny
    holy="$(tr -d "\"'\\\\" <<<"$nizky")"

    # 0) pracovni slozka (cwd): relativni "echo x > settings.json" uvnitr .claude nazev slozky neobsahuje
    case "$(zona_cwd)" in
      tajne)   # i cteni je unik; projde jen odchod (cd, pwd)
        c0="$(tr ';&|' '\n\n\n' <<<"$holy" | sed -E 's/^[[:space:]]+//' | grep -Ev '^(cd|pwd)([[:space:]]|$)|^$')"
        if [ -n "$c0" ] || grep -Eq '[<>`]|\$\(' <<<"$holy"; then
          deny "Strazce P2: pracovni slozka je misto s tajemstvim ($zakladna). Vrat se do projektu (cd)."
        fi ;;
      zamek)
        jen_cteni "$holy" || deny "Strazce P2: pracovni slozka je uvnitr .claude ($zakladna). Odtud agent smi jen cist."
        ;;
      podslozka)   # skills/agents/commands/worktrees: volne, dokud prikaz nemuze vylezt do .claude:
                   # tolik "..", kolik je urovni pod .claude, nebo cd -, popd, cd $X (cil nevime)
        hloubka="$(normalizuj "$zakladna" | sed 's#.*/\.claude##' | tr -cd / | wc -c)"
        tecky="$(grep -o '\.\.' <<<"$holy" | wc -l)"
        if { [ "$tecky" -ge "$hloubka" ] || grep -Eq '(^|[^[:alnum:]_-])(cd|pushd)[[:space:]]+[-$`]|(^|[^[:alnum:]_-])popd' <<<"$holy"; } \
           && ! jen_cteni "$holy"; then
          deny "Strazce P2: z podslozky .claude ($zakladna) prikaz miri ven (.., cd, popd). Zapis mimo ni dela clovek."
        fi ;;
    esac

    # 0a) promenna nebo substituce ($X, ${X}, $(...), `...`) = nevyhodnotitelne: hook nevi, co z ni vznikne.
    #     Spolu s chranenym jmenem nebo jeho kusem blokuje (tajemstvi vzdy, zamek mimo cteni).
    if grep -Eq '\$[[:alpha:]_{(]|`' <<<"$holy"; then
      ocisteny="$(sed -E 's/\.env\.(example|sample|template)//g' <<<"$holy")"
      if grep -Eq '\.en(v|[^[:alnum:]_.]|$)|\.ss(h|[^[:alnum:]_]|$)|\.aw(s|[^[:alnum:]_]|$)|config/gh|secret|credential|\.netrc|\.git-cred|id_rsa|id_ed' <<<"$ocisteny"; then
        deny "Strazce P2: prikaz sklada nazev z promenne a zminuje tajemstvi (.env, .ssh, .aws, secrets). Hook to nevyhodnoti, proto blokuje."
      fi
      if grep -Eq '\.cl|claude|settings|hooks' <<<"$holy" && ! jen_cteni "$holy"; then
        deny "Strazce P2: prikaz sklada cestu z promenne a zminuje .claude/settings/hooks. Mimo cteni blokuji."
      fi
    fi

    # 1) tajemstvi v prikazu (.env.example a spol. jsou v poradku)
    for text in "$nizky" "$holy"; do
      ocisteny="$(sed -E 's/\.env\.(example|sample|template)//g' <<<"$text")"
      if grep -Eq '(^|[^[:alnum:]_])\.env([^[:alnum:]_-]|$)' <<<"$ocisteny"; then
        deny "Strazce P2: prikaz saha na .env. Klice cte jen aplikace za behu, ne agent."
      fi
    done
    if grep -Eq '\.ssh([/[:space:]]|$)|id_rsa|id_ed25519|\.aws(/|[[:space:]]|$)|\.config/gh([/[:space:]]|$)|\.git-credentials|(^|[[:space:]/~])\.netrc' <<<"$holy"; then
      deny "Strazce P2: prikaz saha na prihlasovaci udaje (SSH, AWS, gh, git)."
    fi
    if grep -Eq '(^|[[:space:]/=])secrets/' <<<"$holy"; then
      deny "Strazce P2: prikaz saha do slozky secrets/."
    fi
    # 1a) prikazy, ktere prihlasovaci udaj vypisi na vystup (a tim do kontextu modelu)
    if grep -Eq '(^|[^[:alnum:]_-])gh[[:space:]]+auth[[:space:]]+token|(^|[^[:alnum:]_-])gh[[:space:]]+auth[[:space:]]+status[^;&|]*(--show-token|[[:space:]]-[[:alpha:]]*t([[:space:]]|$))|(^|[^[:alnum:]_-])aws[[:space:]]+([^;&|]*[[:space:]])?(configure[[:space:]]+(get|export-credentials)|sts[[:space:]]+get-session-token)|git[[:space:]]+([^;&|]*[[:space:]])?credential[[:space:]]+fill|security[[:space:]]+find-(generic|internet)-password|gcloud[[:space:]]+auth[[:space:]]+([^;&|]*[[:space:]])?print-[a-z-]*token|az[[:space:]]+account[[:space:]]+get-access-token|gh_token|github_token|aws_secret_access_key|aws_session_token' <<<"$holy"; then
      deny "Strazce P2: prikaz vypisuje prihlasovaci udaj (token, heslo). Udaje do kontextu agenta nepatri."
    fi
    # 1b) glob, ktery by rozbalil .env (cat .e*, cat .en?, cat .[e]nv, cat .*)
    set -f   # rozdelit na slova BEZ rozbalovani globu proti disku
    for slovo in $holy; do
      case "$slovo" in
        *'*'* | *'?'* | *'['*)
          for tajny in .env .env.local .env.production; do
            # shellcheck disable=SC2053  # zamerne: $slovo je vzor
            if [[ "$tajny" == $slovo || "./$tajny" == $slovo ]]; then
              set +f
              deny "Strazce P2: vzor '$slovo' by rozbalil $tajny."
            fi
          done ;;
      esac
    done
    set +f
    # 1c) zamek: cokoli kolem .claude/settings*, .claude/hooks a ~/.claude jen pro cteni (deny-by-default)
    if zminuje_claude "$holy" && ! jen_cteni "$holy"; then
      deny "Strazce P2: slozku .claude (nastaveni, hooky) meni jen clovek. Agent ji smi jen cist (cat, jq, git diff)."
    fi

    # 2) rekurzivni mazani
    # pred "rm" smi byt i lomitko (/bin/rm) a puvodne uvozovka (bash -c 'rm -rf ...'), ktere deny pravidlo nechyti
    if grep -Eq '(^|[;&|(`[:space:]/])rm[[:space:]]([^;&|]*[[:space:]])?(-[[:alpha:]]*[rR][[:alpha:]]*|--recursive)([[:space:]]|$)' <<<"$holy"; then
      deny "Strazce P2: rekurzivni mazani (rm -r/-rf) dela jen clovek, rucne a po kontrole cesty."
    fi

    # 3) slouceni PR z prikazove radky (na main byva navazane nasazeni)
    if grep -Eq '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)' <<<"$holy"; then
      deny "Strazce P2: slouceni PR (gh pr merge) dela clovek po kontrole diffu."
    fi

    # 4) git push
    if grep -Eq '(^|[;&|[:space:]/])git[[:space:]]([^;&|]*[[:space:]])?push([[:space:]]|$)' <<<"$holy"; then
      chranena='(^|/)(main|master|production)$'
      hola_vetev='^(refs/)?(heads/)?(main|master|production)$'
      while IFS= read -r usek; do
        set -f
        for t in ${usek#*push}; do
          case "$t" in
            --all | --mirror) set +f; deny "Strazce P2: push --all/--mirror posle i main. Pushni jednu vetev." ;;
            -*) continue ;;
          esac
          t="${t#+}"
          if [[ "$t" == *:* ]]; then
            # refspec zdroj:cil -> rozhoduje CIL (HEAD:main, HEAD:heads/main, @:refs/heads/main, ":" = vsechny shodne)
            if [ "$t" = ":" ] || [[ "${t##*:}" =~ $chranena ]]; then
              set +f; deny "Strazce P2: push na chranenou vetev ($t). Zmeny jdou pres vetev a pull request."
            fi
          elif [[ "$t" =~ $hola_vetev || "$t" =~ ^refs/.*/(main|master|production)$ ]]; then
            set +f; deny "Strazce P2: push na chranenou vetev (main/master/production). Zmeny jdou pres vetev a pull request."
          fi
        done
        set +f
      done < <(grep -Eo 'git[[:space:]]([^;&|]*[[:space:]])?push([[:space:]][^;&|]*)?' <<<"$holy")
      if grep -Eq -- '--force|[[:space:]]-[[:alnum:]]*f[[:alnum:]]*([[:space:]]|$)|[[:space:]]\+[^[:space:]]' <<<"$holy"; then
        deny "Strazce P2: force push prepisuje historii. Jen clovek, rucne."
      fi
      vetev="$(git -C "$projekt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
      if [ "$vetev" = "main" ] || [ "$vetev" = "master" ] || [ "$vetev" = "production" ]; then
        deny "Strazce P2: jsi na vetvi $vetev. Vytvor vetev (git switch -c ...) a pushni ji."
      fi
    fi
    ;;
esac

exit 0
