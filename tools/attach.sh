#!/bin/bash
# Conecta ao Chrome do usuário via CDP
# Uso: ./attach.sh [-s nome_da_sessao]
#
# Lê o DevToolsActivePort da config do Chrome e anexa o playwright-cli.
# Retorna 0 em caso de sucesso, 1 se o Chrome não está rodando ou não há porta de debug.

set -euo pipefail

SESSION_NAME=""
while getopts "s:" opt; do
  case $opt in
    s) SESSION_NAME="-s=$OPTARG" ;;
    *) echo "Uso: $0 [-s nome_da_sessao]" >&2; exit 1 ;;
  esac
done

DEVTOOLS_FILE="$HOME/.config/google-chrome/DevToolsActivePort"

if [[ ! -f "$DEVTOOLS_FILE" ]]; then
  echo "Chrome não está rodando com remote debugging habilitado." >&2
  echo "Habilite em chrome://inspect/#remote-debugging" >&2
  exit 1
fi

PORT=$(sed -n 1p "$DEVTOOLS_FILE")
WS_PATH=$(sed -n 2p "$DEVTOOLS_FILE")

if [[ -z "$PORT" || -z "$WS_PATH" ]]; then
  echo "Arquivo DevToolsActivePort inválido" >&2
  exit 1
fi

CDP_URL="ws://127.0.0.1:${PORT}${WS_PATH}"

# Verifica se já está conectado
if playwright-cli $SESSION_NAME tab-list &>/dev/null; then
  echo "Já conectado"
  playwright-cli $SESSION_NAME tab-list
  exit 0
fi

# Anexa
echo "Conectando ao Chrome em $CDP_URL..."
playwright-cli $SESSION_NAME attach --cdp="$CDP_URL"

echo "Conectado. Abas:"
playwright-cli $SESSION_NAME tab-list
