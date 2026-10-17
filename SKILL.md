---
name: browser-automation
description: Use when automating web apps the user is already logged into (Teams, Outlook, Jira web, internal tools) via the user's own Chrome over CDP — read/send messages, scrape data, fill forms, record video — and MCP tools or APIs are unavailable or insufficient.
inclusion: auto
version: 2026-10-17T13:37
---

# Browser Automation

## Visão Geral

Dirige o Chrome logado do usuário via CDP (Chrome DevTools Protocol) com `playwright-cli`
para automatizar aplicações web sem exigir logins separados nem credenciais de API: as
sessões existentes do usuário (cookies de login) ficam disponíveis.

## Quando Usar

- Automatizar apps web em que o usuário já está logado (Teams, Outlook, Jira web, ferramentas internas)
- Ler ou enviar mensagens, extrair dados, preencher formulários, navegar fluxos
- Gravar vídeo das interações no navegador para demos ou depuração
- Quando ferramentas MCP ou APIs não estão disponíveis ou não bastam

**Quando NÃO usar:** leitura simples de página pública (use `web_fetch`); quando existe
MCP/API dedicada e suficiente para a tarefa.

## Referência Rápida

| Operação | Comando |
|---|---|
| Conectar ao Chrome | `tools/attach.sh` (ou `tools/attach.sh -s <sessao>`) |
| Listar abas | `playwright-cli -s=<sessao> tab-list` |
| Abrir aba nova | `run-code` com `window.open('URL', '_blank')` — nunca `tab-new`/`goto` |
| Ver estado / refs | `playwright-cli -s=<sessao> snapshot` |
| Clicar | `playwright-cli -s=<sessao> click <ref>` |
| Preencher | `playwright-cli -s=<sessao> fill <ref> "texto"` |
| Ler conteúdo | `evaluate` + `innerText`/`innerHTML` (preferir a screenshot) |
| Verificação visual | `playwright-cli -s=<sessao> screenshot` (último recurso) |
| Erros da página | `playwright-cli -s=<sessao> console error` |
| Encerrar | `playwright-cli -s=<sessao> detach` — **nunca** `close` |

## Pré-requisitos (configuração do usuário, uma vez)

1. Abrir o Chrome normalmente (sem flags especiais)
2. Ir em `chrome://inspect/#remote-debugging` e habilitar
3. Instalar a extensão do Playwright:
   https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm

É só isso. O agente cuida de todo o resto. Procedimento completo de conexão, regras de
navegação e diagnóstico em [`runbooks/browser-cdp-agente.md`](runbooks/browser-cdp-agente.md).

## Como funciona

O agente conecta ao Chrome em execução do usuário via CDP, abre abas e interage com as
páginas usando `playwright-cli`. As sessões existentes do usuário (cookies de login) ficam disponíveis.

```bash
# Conectar ao Chrome do usuário (o agente faz isso automaticamente)
P=$HOME/.config/google-chrome/DevToolsActivePort
PORT=$(sed -n 1p "$P"); WS=$(sed -n 2p "$P")
playwright-cli attach --cdp="ws://127.0.0.1:${PORT}${WS}"

# Abrir uma aba nova (nunca navegar nas abas existentes do usuário)
playwright-cli -s=<sessao> run-code "async (page) => { await page.evaluate(() => window.open('https://example.com', '_blank')); }"

# Interagir
playwright-cli -s=<sessao> snapshot
playwright-cli -s=<sessao> click <ref>
playwright-cli -s=<sessao> fill <ref> "texto"
playwright-cli -s=<sessao> screenshot
```

## Regras

### Navegação

- **`window.open`, nunca `tab-new` ou `goto`** — `tab-new` abre na janela do dashboard
  e cobre a conversa. Sempre: `tab-select` para uma aba na janela de destino →
  `run-code` com `window.open('URL', '_blank')`.
- **Nunca `close`** — usar `detach` ao terminar
- **Snapshot novo antes de interagir** — os refs morrem após a navegação
- **Duas janelas**: dashboard (conversa) e trabalho (Teams, etc.). Abas novas sempre na
  janela de trabalho.

### Lendo conteúdo

Prioridade (para qualquer site):

1. `evaluate` + `innerText`/`innerHTML` → ler texto e dados
2. `snapshot` → refs de elementos e confirmar estado
3. `screenshot` → último recurso, só para verificação visual (layout, imagens)

```javascript
// Ler o conteúdo da página
page.evaluate(() => document.querySelector('[data-tid="app-layout-area--main"]').innerText)
```

### Sessões paralelas (chat × cron × sub-agent)

- A conexão do `playwright-cli` é **por processo**: crons e sub-agents não herdam
  a conexão do chat. Uma sessão nova conecta via `tools/attach.sh`.
- Todos usam o **mesmo Chrome**: duas sessões mexendo na mesma aba interferem. Regra: cada
  processo trabalha na própria aba; leituras de DB local (IndexedDB) não tocam a tela e podem
  rodar em paralelo.
- Nomear as sessões quando vários processos navegam: `-s=<nome-da-tarefa>` em todos os comandos daquele
  processo (ou `PLAYWRIGHT_CLI_SESSION=<nome>`).
- **Nunca** `close`, `close-all`, `kill-all` ou `delete-data` no navegador do usuário —
  fecha janelas e apaga logins. Para sair, `detach`.

### Interceptação de rotas — não usar no navegador do usuário

`playwright-cli route "<padrao>" --status=…/--body=…` simula respostas ou bloqueia
recursos. Útil para testes em sessões isoladas. No Chrome do usuário **não usar**:
a regra vale para a aba inteira e quebra o Teams/ADM que ele está usando. Se for essencial,
remover imediatamente com `playwright-cli unroute`.

## Erros Comuns e Solução de Problemas

Ordem (do mais leve ao mais pesado):

1. **Erros de JavaScript da página**: `playwright-cli console error`
2. **Requisições falhas**: montar um listener que imprime só status + path (sem headers/body,
   que carregam credenciais):
   ```bash
   playwright-cli run-code "async page => { page.on('requestfailed', r => console.log('FAILED', r.method(), r.url().split('?')[0], r.failure()?.errorText)); page.on('response', r => { if (r.status() >= 400) console.log('HTTP', r.status(), r.url().split('?')[0]); }); }"
   ```
   Evitar `requests` / `request <n>` / `response-headers`: eles mostram headers e body com
   tokens (exigem aprovação).
3. **Elemento não responde ao clique**: checar via `page.evaluate` se está visível, desabilitado
   ou coberto por outro elemento (`document.elementFromPoint` no centro do
   `getBoundingClientRect`).
4. **Esperar a página assentar**: `page.waitForLoadState('networkidle')` ou
   `locator.waitFor({ state: 'visible' })` dentro do `run-code`.
5. **Trace (último recurso)**: `playwright-cli tracing-start` → reproduzir → `tracing-stop`.
   Grava DOM, rede e console de cada passo. ⚠️ Num navegador logado o trace
   contém **tokens e cookies**: salvar só em `$KIROCREW_SCRATCH`, apagar depois da
   análise, nunca enviar para `trace.playwright.dev` nem anexar em tickets.

Para capturar **uma resposta de API específica** (ex.: mensagens do Teams), em vez de um listener:
```javascript
const r = await page.waitForResponse(u => u.url().includes('/messages'));
return await r.json();
```

## Gravação de vídeo

Grava as interações no navegador para demos, testes ou depuração.

```bash
# Iniciar gravação HD com cursor animado
playwright-cli -s=<sessao> video-start --size 1920x1080 --cursor

# Marcar capítulos
playwright-cli -s=<sessao> video-chapter "Abrindo o menu X"

# Destacar visualmente cada ação (opcional)
playwright-cli -s=<sessao> video-show-actions

# Parar e salvar
playwright-cli -s=<sessao> video-stop
# Gera .webm em ~/.kiro/crew/playwright-snapshots/
```

| Flag | Efeito | Default |
|---|---|---|
| `--size 1920x1080` | Resolução | 800x800 (texto ilegível) |
| `--fps 30` | Quadros por segundo | 25 |
| `--cursor` | Cursor animado + destaque do elemento | Sem cursor |

- **Sempre** gravar em 1920x1080 — o default deixa o texto ilegível.
- Pode gerar vários segmentos `.webm`; o principal é o maior.
- Entregar ao usuário com `file_send` (download no dashboard).
- Converter para mp4/gif se precisar: `ffmpeg -i video.webm -c:v libx264 video.mp4`

## Padrões específicos por app

Guias detalhados por aplicação ficam em `apps/`. Cada guia traz estrutura da UI,
seletores, formatos de ID e padrões de extração — só técnica, sem dados de contas/pessoas.

| App | Guia | Cobre |
|---|---|---|
| Microsoft Teams | [`apps/teams.md`](apps/teams.md) | Ler/enviar mensagens, @menções, busca, lista de chats, `conversationId`, leitura sem marcar como lido (IndexedDB), deep links, gotchas de virtualização |

**Ler primeiro o guia do app antes de automatizá-lo** — ele mapeia os seletores e as
pegadinhas que não dá para adivinhar. Mapeamentos de IDs reais (contatos, canais) de um
ambiente específico ficam nos seus próprios steerings/notas, nunca nesta skill.

- O shell do agente não tem `$DISPLAY`. A conexão CDP funciona via loopback.
- Se o Chrome reiniciar, o UUID muda e o agente reconecta.
- Popups de extensão (como o Jam) ficam fora do CDP — não dá para automatizar.

## Ferramentas e runbooks

| Arquivo | Finalidade |
|---|---|
| `tools/attach.sh` | Conectar ao Chrome do usuário e devolver os dados da sessão |
| `runbooks/browser-cdp-agente.md` | Setup do Chrome, conexão CDP, regras de navegação e diagnóstico |
| `runbooks/browser-gravacao-video.md` | Gravar a navegação do agente em vídeo |
| `apps/teams.md` | Guia do Microsoft Teams |

## Veja também

- skill `web-browse` — padrões de navegação de mais alto nível
- skill `web-preview` — preview de servidores de dev locais
- skill `browser-auth` — gestão de sessões logadas
