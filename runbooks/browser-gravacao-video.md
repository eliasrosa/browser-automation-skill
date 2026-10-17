# Browser — Gravação de vídeo

> Gravar a navegação do agente (ex.: testar um menu, demonstrar um fluxo) e entregar
> ao usuário. Conexão com o browser: `browser-cdp-agente.md`.

## playwright-cli video

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

| Flag | O que faz | Default |
|---|---|---|
| `--size 1920x1080` | Resolução | 800x800 (texto ilegível) |
| `--fps 30` | Frames/segundo | 25 |
| `--cursor` | Cursor animado + highlight do elemento | Sem cursor |

- **Sempre** gravar em 1920x1080 — no default o texto fica ilegível.
- Pode gerar mais de um segmento `.webm`; o principal é o maior.
- Entregar ao usuário com `file_send` (download no dashboard).
- Converter para mp4/gif, se preciso: `ffmpeg -i video.webm -c:v libx264 video.mp4`.

## Jam (extensão do Chrome) — complementar

Grava tela + console + network + eventos do usuário numa URL compartilhável.

| Ação | Agente consegue? |
|---|---|
| Ler/abrir Jams existentes (`jam.dev/s/<id>`) | ✅ Sim |
| Iniciar gravação pela extensão | ❌ Não (popup de extensão fica fora do CDP) |

Uso típico: o usuário grava pelo Jam e o agente analisa o resultado.
