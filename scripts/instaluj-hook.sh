#!/bin/sh
# Zapne pre-commit hook s gitleaks v tomto klonu repa. Spusť jednou po každém klonování. v1.3 · 2026-10-12
# core.hooksPath je lokální nastavení gitu, klonem se nepřenáší.
# Hook je pojistka na tvém počítači, ne zámek: viz hlavička .githooks/pre-commit.
set -eu
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Spusť skript uvnitř git repa." >&2; exit 1; }
cd "$ROOT"
if [ ! -f .githooks/pre-commit ] || ! grep -q 'gitleaks git' .githooks/pre-commit; then
  echo "STOP: .githooks/pre-commit chybí nebo nevolá gitleaks. Obnov ho ze šablony P1." >&2
  exit 1
fi
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
echo "Hook zapnutý: core.hooksPath = $(git config core.hooksPath)"
if command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks: $(gitleaks version)"
else
  echo "POZOR: gitleaks chybí. Dokud ho nenainstaluješ, každý commit se zastaví (záměrně)."
fi
