# Microsoft Teams — Guia de automação

> Padrões de automação do Teams web (`teams.cloud.microsoft` / `teams.microsoft.com`)
> via `playwright-cli` sobre o Chrome logado do usuário. Só estrutura, seletores e
> técnica — nenhum dado de pessoa, grupo ou conta vai aqui. IDs reais de contatos e
> canais, quando a tarefa exigir, ficam nos steerings/notas do próprio usuário.
>
> Regras gerais de conexão, abas e sessões estão na raiz da skill (`../SKILL.md`).

## Regras de uso no Teams

1. **Filtros e busca desligados por padrão.** Find in chat (Ctrl+F), busca global,
   filtros (Date, From, etc.) e a aba Unread só são ativados para pesquisar. Ao terminar,
   fechar o painel, limpar os filtros e voltar à aba Chats normal.
2. **Abrir um chat marca as mensagens como lidas.** Se o objetivo é levantar pendências
   sem alterar o estado de leitura, usar o cache local do IndexedDB (abaixo), não abrir o chat.
3. **Não responder sem pedido.** Ler e resumir não autoriza enviar. Enviar só com
   confirmação explícita do texto pelo usuário.

## Referência Rápida — operações

| Operação | Como |
|---|---|
| Ler o chat aberto | `evaluate` + `innerText` em `[data-tid="app-layout-area--main"]` |
| Enviar mensagem | abrir chat → `fill` no textbox → `click` no botão Send |
| @menção | digitar `@Nome` → aguardar listbox Suggestions → `click` na option |
| Buscar no chat ativo | `Ctrl+F` → digitar no searchbox → `Enter` |
| Busca global | `Ctrl+Alt+E` → combobox "Search or ask Copilot" |
| Filtrar o sidebar | textbox "Filter by person or chat name" (limpar ao terminar) |
| Listar itens de chat | `querySelectorAll('span[id^="title-chat-list-item_"]')` |
| Ler sem marcar como lido | cache IndexedDB `Teams:replychain-manager:…` |

## Estrutura da UI

### Sidebar do Chat — controles (seletores de snapshot)

| Elemento | Seletor snapshot |
|---|---|
| Novo chat/mensagem | `button "New message"` |
| Filtro da lista | `textbox "Filter by person or chat name"` |
| Fechar filtro | `button "Close filter text box"` |
| Aba Não lidos | `button "Unread"` |
| Aba Chats | `button "Chats"` |
| Aba Meeting chats | `button "Meeting chats"` |
| Mais opções da lista | `button "More list options"` |

### Abas e quick views

- **Chats**: lista geral. Pode ter pastas/seções custom (Favorites + pastas do usuário).
- **Unread**: lista **todos** os não lidos, inclusive chats mutados antigos que não aparecem
  marcados na lista geral. Para levantar pendências, conferir a lista geral **e** a aba Unread.
- **Meeting chats**: só conversas de reunião.
- Dentro de Chats, expandindo: **Drafts**, **Mentions**, **Favorites**.

### Editor de mensagem

| Elemento | Seletor DOM | Seletor snapshot |
|---|---|---|
| Campo de texto | `[data-tid="app-layout-area--main"] [role="textbox"]` | `textbox "Type a message"` |
| Botão enviar | `button[aria-label*="Send"]` | `button "Send (Ctrl+Enter)"` |

## Identificação de chats (`conversationId`)

Cada item do sidebar é um `span` com `id="title-chat-list-item_<conversationId>"`. O
`conversationId` é **estável entre sessões** — preferir ele ao nome exibido, que muda
(grupos sem nome aparecem com a lista de participantes). O `id` do treeitem (`menurdXX`) é
volátil: muda a cada reload, nunca guardar.

Três formatos de `conversationId`:

| Tipo | Formato |
|---|---|
| Chat 1:1 (pessoa ou bot) | `19:<userIdA>_<userIdB>@unq.gbl.spaces` — os dois userIds em ordem alfabética |
| Grupo / canal | `19:<hash>@thread.v2` |
| Meeting chat | `19:meeting_<base64>@thread.v2` |

- Num 1:1, um dos userIds é sempre o da conta logada; o outro é o do contato.
- **Não** quebrar o `conversationId` no `_` como se fosse "thread + pessoa": o ID da
  conversa é a string inteira.
- **Gotcha**: os `span[id^="title-chat-list-item_"]` só existem na DOM com as pastas
  (Favorites, pastas custom, Chats) **expandidas** e sem o filtro Unread ativo. Se a extração
  vier vazia, expandir as pastas, extrair, e recolher de volta ao estado anterior.

## Padrões técnicos

### Ler o chat aberto (o que está no DOM agora)

```javascript
// Pega todo o texto já carregado — não depende de scroll visual
page.evaluate(() => document.querySelector('[data-tid="app-layout-area--main"]').innerText)
```

**Gotchas de leitura:**
- `mouse.wheel` não rola o chat: o scroll fica numa div interna, não no body.
- O Teams **virtualiza** as mensagens: rolar descarrega as antigas do DOM. O `innerText`
  pega só o buffer carregado. Para histórico longo, usar a busca (Find/global).

### Abrir um chat

```javascript
// Pelo conversationId (preferido — não depende do nome exibido)
document.getElementById('title-chat-list-item_' + id)
  ?.closest('[role="treeitem"]')?.click();

// Pelo nome (fallback)
[...document.querySelectorAll('span[id^="title-chat-list-item_"]')]
  .find(s => s.textContent.includes('<nome>'))
  ?.closest('[role="treeitem"]')?.click();
```

Se não achar: o chat pode estar numa pasta recolhida (ver gotcha acima) ou fora da lista
carregada — usar o filtro "Filter by person or chat name" e limpar ao terminar.

### Extrair a lista de chats

```javascript
// Com as pastas expandidas e sem filtro Unread
[...document.querySelectorAll('span[id^="title-chat-list-item_"]')]
  .map(s => ({ conversationId: s.id.replace('title-chat-list-item_', ''), name: s.innerText.trim() }))
```

### Buscar no chat ativo

```bash
playwright-cli -s=<sessao> run-code "async (page) => { await page.keyboard.press('Control+f'); }"
playwright-cli -s=<sessao> click <ref-searchbox>
playwright-cli -s=<sessao> type "termo" --submit   # fill direto às vezes não dispara a busca
# Ao terminar: Escape ou "Close" + limpar filtros (regra 1)
```

Find também expõe filtros por **data** (datepicker From/To ou presets Today/Yesterday/This
week/This month → Apply), por **pessoa** (From), e por tipo (Messages, Attachment, Mentions).

### Capturar uma resposta de API específica

Em vez de abrir o chat, esperar a chamada de rede do próprio Teams:

```javascript
const r = await page.waitForResponse(u => u.url().includes('/messages'));
return await r.json();
```

### Ler sem marcar como lido (IndexedDB)

O Teams mantém as mensagens em cache no IndexedDB:

```
DB    : Teams:replychain-manager:…
Store : replychains
Key   : [conversationId, replyChainId]
Valor : cada registro tem um messageMap com as mensagens
```

Ler desse cache **não marca o chat como lido**. A cobertura depende do que o usuário já
abriu naquele navegador. Leituras de IndexedDB não tocam a tela, então podem rodar em
paralelo com outra sessão sem interferir na aba ativa.

### Deep link para um chat

```
https://teams.cloud.microsoft/l/chat/<conversationId>/conversations
```

Fallback de rede quando o item não está na lista carregada; abrir numa aba nova com
`window.open(url, '_blank')` (nunca `goto`/`tab-new`, ver `../SKILL.md`).

## Onde ficam os IDs reais

Este guia é só a técnica. Os `conversationId`/`userId` concretos de contatos, grupos e
reuniões de um ambiente específico ficam nos **steerings ou notas do próprio usuário** —
nunca neste repositório de skill, que é público.
