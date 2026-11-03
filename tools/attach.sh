#!/bin/bash
# Conecta ao Chrome do usuário via CDP
# Uso: ./attach.sh [-s nome_da_sessao] [--print-url]
#
# Lê o DevToolsActivePort do perfil do Chrome e anexa o playwright-cli.
#   --print-url  só mostra a URL CDP (usado pelo check.py), sem conectar
#
# Perfil: Google Chrome por padrão; também acha Chrome Beta, Chromium e Brave.
# Para outro perfil, defina CHROME_USER_DATA_DIR (a pasta que tem o DevToolsActivePort).
# Retorna 0 em caso de sucesso, 1 se o Chrome não está rodando ou não há porta de debug.

set -euo pipefail

SESSION_NAME=""
PRINT_URL=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SESSION_NAME="-s=${2:?nome da sessão}"; shift 2 ;;
    -s=*) SESSION_NAME="$1"; shift ;;
    -s?*) SESSION_NAME="-s=${1#-s}"; shift ;;   # -snome (formato do getopts antigo)
    --print-url) PRINT_URL=1; shift ;;
    *) echo "Uso: $0 [-s nome_da_sessao] [--print-url]" >&2; exit 1 ;;
  esac
done

# playwright-cli: o do PATH, senão o instalado pelo Kiro Crew (Settings → Browser)
CREW_HOME="${KIROCREW_HOME:-$HOME/.kiro/crew}"
PWCLI="$(command -v playwright-cli || true)"
if [[ -z "$PWCLI" && -x "$CREW_HOME/playwright-cli/bin/playwright-cli" ]]; then
  PWCLI="$CREW_HOME/playwright-cli/bin/playwright-cli"
fi

find_devtools_file() {
  if [[ -n "${CHROME_USER_DATA_DIR:-}" ]]; then
    echo "${CHROME_USER_DATA_DIR%/}/DevToolsActivePort"
    return
  fi
  local d
  for d in "$HOME/.config/google-chrome" "$HOME/.config/google-chrome-beta" \
           "$HOME/.config/chromium" "$HOME/.config/BraveSoftware/Brave-Browser" \
           "$HOME/Library/Application Support/Google/Chrome"; do
    if [[ -s "$d/DevToolsActivePort" ]]; then
      echo "$d/DevToolsActivePort"
      return
    fi
  done
  echo "$HOME/.config/google-chrome/DevToolsActivePort"
}

DEVTOOLS_FILE="$(find_devtools_file)"

if [[ ! -f "$DEVTOOLS_FILE" ]]; then
  echo "Chrome não está rodando com remote debugging habilitado." >&2
  echo "Habilite em chrome://inspect/#remote-debugging" >&2
  exit 1
fi

PORT=$(sed -n 1p "$DEVTOOLS_FILE")
WS_PATH=$(sed -n 2p "$DEVTOOLS_FILE")

if [[ -z "$PORT" || -z "$WS_PATH" ]]; then
  echo "Arquivo DevToolsActivePort inválido: $DEVTOOLS_FILE" >&2
  exit 1
fi

CDP_URL="ws://127.0.0.1:${PORT}${WS_PATH}"

if [[ "$PRINT_URL" -eq 1 ]]; then
  echo "$CDP_URL"
  exit 0
fi

if [[ -z "$PWCLI" ]]; then
  echo "playwright-cli não encontrado. No Kiro Crew: Settings → Browser (instala com um clique)." >&2
  echo "Fora do Crew: npm install -g @playwright/cli@latest (Node.js 20+)" >&2
  exit 1
fi

# Verifica se já está conectado
if "$PWCLI" $SESSION_NAME tab-list &>/dev/null; then
  echo "Já conectado"
  "$PWCLI" $SESSION_NAME tab-list
  exit 0
fi

# Anexa
echo "Conectando ao Chrome em $CDP_URL..."
"$PWCLI" $SESSION_NAME attach --cdp="$CDP_URL"

echo "Conectado. Abas:"
"$PWCLI" $SESSION_NAME tab-list
