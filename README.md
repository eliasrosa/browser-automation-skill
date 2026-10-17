# Browser Automation

Skill do Kiro Crew para automatizar aplicações web pelo Chrome logado do usuário usando CDP (Chrome DevTools Protocol).

## O que faz

- **Dirige sessões logadas** — Automatiza Teams, Outlook, Jira, ferramentas internas usando os logins que o usuário já tem
- **Sem credenciais** — Usa os cookies de sessão do navegador, não chaves de API
- **Seguro por design** — Abre abas novas, nunca navega nas abas existentes do usuário
- **Gravação de vídeo** — Captura interações para demos ou depuração

## Instalação

### Como skill do Kiro Crew

```bash
# Copiar para o diretório de skills
cp -r . ~/.kiro/crew/skills/browser-automation/

# Ou instalar pelo registry (quando publicada)
# kirocrew skill install browser-automation
```

### Configuração do usuário (uma vez)

1. Abrir o Chrome normalmente
2. Ir em `chrome://inspect/#remote-debugging` e habilitar
3. Instalar a [extensão do Playwright](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm)

## Uso

O agente cuida da conexão e da navegação automaticamente. O usuário só pede:

- "Envia uma mensagem para X no Teams"
- "Lê as últimas mensagens do canal Y"
- "Abre o painel admin e verifica Z"
- "Grava um vídeo de mim testando esse fluxo"

### Uso manual

```bash
# Conectar ao Chrome
./tools/attach.sh

# Ou com nome de sessão (para uso em paralelo)
./tools/attach.sh -s minha-tarefa

# Depois usar o playwright-cli
playwright-cli -s=minha-tarefa snapshot
playwright-cli -s=minha-tarefa click <ref>
playwright-cli -s=minha-tarefa fill <ref> "texto"
```

## Regras principais

1. **`window.open`, nunca `tab-new`** — Abas novas via JavaScript, não pelo CLI, para ficar na janela certa
2. **Nunca `close`** — Usar `detach` ao terminar
3. **Snapshot novo antes de interagir** — Os refs de elemento morrem após a navegação
4. **Ler com `evaluate`, não screenshot** — `innerText` é mais rápido e mais confiável

## Estrutura

```
browser-automation/
├── SKILL.md           # Documentação completa da skill
├── README.md          # Este arquivo
├── LICENSE            # MIT
├── apps/              # Guias por aplicação (estrutura, seletores, padrões)
│   └── teams.md       # Microsoft Teams
└── tools/
    └── attach.sh      # Conecta ao Chrome do usuário
```

## Apps suportados

Guias detalhados em `apps/`:

- **Microsoft Teams** ([`apps/teams.md`](apps/teams.md)) — Chat, busca, menções, `conversationId`, leitura sem marcar como lido (IndexedDB), deep links
- **Apps web genéricos** — Formulários, navegação, extração de dados (padrões na SKILL.md)

Mapeamentos específicos de app (IDs, seletores de ferramentas internas) devem ir nos seus próprios steerings, não nesta skill.

## Gravação de vídeo

```bash
# Iniciar gravação HD
playwright-cli -s=tarefa video-start --size 1920x1080 --cursor

# Marcar capítulos
playwright-cli -s=tarefa video-chapter "Passo 1: abrir configurações"

# Parar e salvar
playwright-cli -s=tarefa video-stop
# → .webm em ~/.kiro/crew/playwright-snapshots/

# Converter para mp4
ffmpeg -i video.webm -c:v libx264 video.mp4
```

## Solução de problemas

1. **Erros da página**: `playwright-cli console error`
2. **Falhas de rede**: montar um listener de response (ver SKILL.md)
3. **Elemento não responde**: checar visibilidade com `evaluate`
4. **Trace (último recurso)**: `tracing-start` → ações → `tracing-stop`

⚠️ Traces contêm credenciais — salvar em scratch, apagar depois da análise.

## Limitações

- O shell do agente não tem `$DISPLAY` — funciona só via loopback
- Reiniciar o Chrome muda o UUID — precisa reconectar
- Popups de extensão (Jam, etc.) ficam fora do CDP

## Licença

MIT

## Relacionados

- [playwright-cli](https://github.com/anthropics/anthropic-tools) — O CLI por baixo
- [Kiro Crew](https://kiro.dev) — Plataforma de agentes autônomos
