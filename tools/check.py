#!/usr/bin/env python3
"""
Pré-check da browser-automation.

Valida o que a skill precisa para dirigir o Chrome do usuário via CDP:
playwright-cli (e o Node.js que ele usa), um Chrome/Chromium instalado, o remote
debugging habilitado (arquivo DevToolsActivePort) e a porta de debug aceitando
conexão. Não conecta nem abre aba: só lê. A localização do DevToolsActivePort vem
do tools/attach.sh (--print-url), a mesma que o attach usa.

Uso:
  python3 tools/check.py

Saída:
  ✓ ou ✗ por requisito, com instrução de correção em caso de falha.
  Exit 0 = tudo OK. Exit 1 = algum requisito falhou.
"""

import os
import re
import shutil
import socket
import subprocess
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
CREW_HOME = os.environ.get("KIROCREW_HOME") or str(Path.home() / ".kiro/crew")
# ID público da extensão Playwright na Chrome Web Store
EXTENSION_ID = "mmlmfjhmonkocbjadbfplnigmagldckm"
CHROME_BINARIES = ("google-chrome", "google-chrome-stable", "google-chrome-beta",
                   "chromium", "chromium-browser", "brave-browser")
PROFILE_ROOTS = ("~/.config/google-chrome", "~/.config/google-chrome-beta",
                 "~/.config/chromium", "~/.config/BraveSoftware/Brave-Browser",
                 "~/Library/Application Support/Google/Chrome")
FIX_PWCLI = ("Kiro Crew: Settings → Browser instala com um clique. "
             "Fora do Crew: npm install -g @playwright/cli@latest (Node.js 20+)")
FIX_DEBUG = "Abra o Chrome → chrome://inspect/#remote-debugging → habilite o remote debugging"

ok = True


def check(label: str, result: bool, fix: str = "") -> None:
    """Imprime ✓ ou ✗ e registra falha."""
    global ok
    print(f"  {'✓' if result else '✗'} {label}")
    if not result:
        if fix:
            print(f"    → {fix}")
        ok = False


def find_pwcli() -> str | None:
    found = shutil.which("playwright-cli")
    crew_cli = Path(CREW_HOME) / "playwright-cli/bin/playwright-cli"
    if not found and os.access(crew_cli, os.X_OK):
        found = str(crew_cli)
    return found


print("Verificando requisitos da browser-automation...\n")

# ---------------------------------------------------------------------------
# Ferramentas
# ---------------------------------------------------------------------------
print("Ferramentas:")
check("Python 3.10+", sys.version_info >= (3, 10),
      f"versão atual: {sys.version.split()[0]} — instale Python 3.10+")

pwcli = find_pwcli()
check("playwright-cli instalado", pwcli is not None, FIX_PWCLI)
if pwcli:
    node = shutil.which("node")
    if node:
        out = subprocess.run([node, "--version"], capture_output=True, text=True).stdout.strip()
        m = re.match(r"v(\d+)", out)
        check(f"Node.js 20+ para o playwright-cli ({out or '?'})",
              bool(m) and int(m.group(1)) >= 20, "Instale o Node.js 20 ou mais novo")
    else:
        check("Node.js no PATH (o playwright-cli roda em Node)", False,
              "Instale o Node.js 20 ou mais novo")

chrome = next((b for b in CHROME_BINARIES if shutil.which(b)), None)
check(f"Chrome/Chromium instalado ({chrome or 'nenhum'})", chrome is not None,
      "Instale o Google Chrome (ou Chromium/Brave)")

# ---------------------------------------------------------------------------
# Navegador: remote debugging e porta
# ---------------------------------------------------------------------------
print("\nNavegador:")
r = subprocess.run(["bash", str(TOOLS / "attach.sh"), "--print-url"],
                   capture_output=True, text=True)
cdp_url = r.stdout.strip() if r.returncode == 0 else ""
check("remote debugging habilitado (DevToolsActivePort)", bool(cdp_url), FIX_DEBUG)
if cdp_url:
    port = int(re.search(r":(\d+)/", cdp_url).group(1))
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2):
            reachable = True
    except OSError:
        reachable = False
    check(f"porta de debug {port} aceitando conexão", reachable,
          "O Chrome foi fechado ou reiniciado: reabra e confirme o remote debugging")

ext = any(
    any(Path(root).expanduser().glob(f"*/Extensions/{EXTENSION_ID}"))
    for root in PROFILE_ROOTS
)
if ext:
    print("  ✓ extensão Playwright instalada (modo extensão do Kiro Crew)")
else:
    print("  • extensão Playwright não encontrada (opcional: só o modo extensão do Kiro Crew usa;")
    print("    o attach por CDP desta skill não precisa dela)")

# Referência completa de comandos do playwright-cli para agentes (opcional)
if pwcli:
    if (Path.home() / ".agents/skills/playwright-cli").is_dir():
        print("  ✓ skill de referência do playwright-cli instalada (~/.agents/skills/playwright-cli)")
    else:
        print("  • skill de referência do playwright-cli ausente (opcional):")
        print("    playwright-cli install --skills agents --global")

# ---------------------------------------------------------------------------
# Resultado final
# ---------------------------------------------------------------------------
print()
if ok:
    print("✓ Todos os requisitos satisfeitos. A skill está pronta para uso.")
    print("  Conectar: bash tools/attach.sh -s <sessao>")
else:
    print("✗ Corrija os itens marcados com ✗ antes de usar a skill.")
    sys.exit(1)
