# Browser — Agente Kiro Crew no Chrome do Usuário

> Procedimento de conexão e as regras gerais de navegação. Estrutura da UI e padrões por
> app ficam em `../apps/`. Gravação de vídeo: `browser-gravacao-video.md`.

## Como funciona

O usuário abre o Chrome normalmente e habilita remote debugging.
O agente faz todo o resto sozinho — conectar, abrir tab, navegar, interagir.

### O que o usuário faz (uma vez)

1. Abrir o Chrome (jeito normal, sem flags)
2. Ir em `chrome://inspect/#remote-debugging` e habilitar
3. Ter a extensão Playwright instalada:
   https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm

Pronto. Nada mais.

### O que o agente faz (internamente)

```bash
# Conectar ao Chrome do usuário (ou usar ../tools/attach.sh)
playwright-cli attach --cdp=ws://127.0.0.1:<porta>/devtools/browser/<UUID>

# Abrir tab isolada (nunca goto na tab do usuário)
# Preferir window.open a partir de uma tab da janela de trabalho (ver Regras);
# tab-new só quando ainda não existe tab na janela de trabalho.
playwright-cli -s=<sessao> run-code "async (page) => { await page.evaluate(() => window.open('https://example.com', '_blank')); }"

# Navegar, ler, interagir
playwright-cli -s=<sessao> snapshot
playwright-cli -s=<sessao> click <ref>
playwright-cli -s=<sessao> fill <ref> "mensagem"
playwright-cli -s=<sessao> screenshot
```

O usuário não vê nem roda esses comandos. Ele pede em linguagem natural e o agente executa.

### Perfil e sessões

Chrome normal = perfil padrão = todas as sessões logadas do usuário (Teams, Jira,
Confluence, ferramentas internas) disponíveis. Sem perfil separado, sem login extra.

## Regras

- **window.open, nunca tab-new nem goto** — `tab-new` cai na janela do
  dashboard e tapa a conversa. Sempre: `tab-select` para tab na janela-alvo
  → `run-code` com `window.open('URL', '_blank')`. Abre na mesma janela.
- **Nunca close** — usar detach ao terminar
- **Snapshot fresco** antes de interagir — refs morrem após navegação
- **Duas janelas**: dashboard (conversa) e trabalho (Teams etc.).
  Tabs novas sempre na janela de trabalho.
- **innerText via evaluate** para ler conteúdo — não screenshot/OCR
- **Prioridade de leitura** (vale para qualquer site):
  1. `evaluate` + `innerText`/`innerHTML` → ler texto e dados
  2. `snapshot` → refs de elementos e confirmar estado
  3. `screenshot` → último recurso, só verificação visual (layout, imagem)

## Limitação atual

O shell do agente não tem $DISPLAY. A conexão CDP funciona via loopback
(mesma rede). Se o Chrome reiniciar, o UUID muda e o agente reconecta.

## Diagnóstico quando a automação falha

Ordem sugerida (do mais leve ao mais pesado):

1. **Erros de JavaScript da página**: `playwright-cli console error`.
2. **Requisições com falha**: ligar um listener que imprime só status + caminho (sem
   cabeçalhos nem corpo, que carregam credencial):
   ```bash
   playwright-cli run-code "async page => { page.on('requestfailed', r => console.log('FALHOU', r.method(), r.url().split('?')[0], r.failure()?.errorText)); page.on('response', r => { if (r.status() >= 400) console.log('HTTP', r.status(), r.url().split('?')[0]); }); }"
   ```
   Evitar `requests` / `request <n>` / `response-headers`: mostram cabeçalhos e corpo com
   token (pedem aprovação por isso).
3. **Elemento não responde ao clique**: checar via `page.evaluate` se está visível,
   desabilitado ou coberto por outro elemento (`document.elementFromPoint` no centro do
   `getBoundingClientRect`).
4. **Esperar a página assentar** antes de ler: `page.waitForLoadState('networkidle')` ou
   `locator.waitFor({ state: 'visible' })` dentro de `run-code`.
5. **Trace (último recurso)**: `playwright-cli tracing-start` → reproduzir → `tracing-stop`.
   Grava DOM, rede e console de cada passo. ⚠️ Num navegador logado o trace contém
   **tokens e cookies**: gravar só em `$KIROCREW_SCRATCH`, apagar logo após a análise,
   nunca enviar a `trace.playwright.dev` nem anexar em chamado.

Para pegar **uma resposta específica de API** (ex.: mensagens do Teams), em vez de listener:
`const r = await page.waitForResponse(u => u.url().includes('/messages')); return await r.json();`.

## Sessões em paralelo (chat × cron × sub-agente)

- A conexão do `playwright-cli` é **por processo**: a cron e os sub-agentes não herdam a do
  chat. Sessão nova conecta com `../tools/attach.sh` (lê `DevToolsActivePort`).
- Todos usam o **mesmo Chrome**: duas sessões mexendo na mesma aba se atrapalham. Regra:
  cada processo trabalha na sua própria aba; leitura de banco local (IndexedDB) não mexe na
  tela e pode rodar em paralelo.
- Nomear a sessão quando houver mais de um processo navegando: `-s=<nome-da-tarefa>` em
  todos os comandos daquele processo (ou `PLAYWRIGHT_CLI_SESSION=<nome>`).
- **Nunca** `close`, `close-all`, `kill-all` ou `delete-data` no navegador do usuário — fecham
  janelas e apagam login. Para sair, `detach`.

## Interceptar requisições (`route`) — não usar no navegador do usuário

`playwright-cli route "<padrão>" --status=…/--body=…` simula respostas ou bloqueia
recursos (imagens, scripts). Útil para teste de front em sessão isolada. No Chrome do
usuário **não usar**: a regra vale para a aba inteira e quebra o app que ele está usando.
Se for indispensável, remover logo depois com `playwright-cli unroute`.

## Referências

- Padrões por aplicação: `../apps/`
- Gravação de vídeo: `browser-gravacao-video.md`
- Visão geral da skill: `../SKILL.md`
