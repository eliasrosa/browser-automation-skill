# Browser Automation

Kiro Crew skill for automating web applications via the user's logged-in Chrome browser using CDP (Chrome DevTools Protocol).

## What it does

- **Drive logged-in sessions** — Automate Teams, Outlook, Jira, internal tools using the user's existing logins
- **No credentials needed** — Uses the browser's session cookies, not API keys
- **Safe by design** — Opens new tabs, never navigates user's existing ones
- **Video recording** — Capture interactions for demos or debugging

## Installation

### As a Kiro Crew skill

```bash
# Copy to skills directory
cp -r . ~/.kiro/crew/skills/browser-automation/

# Or install from registry (when published)
# kirocrew skill install browser-automation
```

### User setup (one time)

1. Open Chrome normally
2. Go to `chrome://inspect/#remote-debugging` and enable
3. Install the [Playwright extension](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm)

## Usage

The agent handles connection and navigation automatically. Users just ask:

- "Send a message to X in Teams"
- "Read the latest messages from channel Y"
- "Open the admin panel and check Z"
- "Record a video of me testing this flow"

### Manual usage

```bash
# Connect to Chrome
./tools/attach.sh

# Or with session name (for parallel use)
./tools/attach.sh -s my-task

# Then use playwright-cli
playwright-cli -s=my-task snapshot
playwright-cli -s=my-task click <ref>
playwright-cli -s=my-task fill <ref> "text"
```

## Key rules

1. **`window.open`, never `tab-new`** — New tabs via JavaScript, not CLI, to stay in the right window
2. **Never `close`** — Use `detach` when done
3. **Fresh snapshot before interacting** — Element refs die after navigation
4. **Read with `evaluate`, not screenshot** — `innerText` is faster and more reliable

## Structure

```
browser-automation/
├── SKILL.md           # Full skill documentation
├── README.md          # This file
├── LICENSE            # MIT
└── tools/
    └── attach.sh      # Connect to user's Chrome
```

## Supported apps

Tested patterns included for:

- **Microsoft Teams** — Chat, search, mentions, @mentions
- **Generic web apps** — Forms, navigation, data extraction

App-specific mappings (IDs, selectors for internal tools) should go in your own steering files, not in this skill.

## Video recording

```bash
# Start HD recording
playwright-cli -s=task video-start --size 1920x1080 --cursor

# Mark chapters
playwright-cli -s=task video-chapter "Step 1: Open settings"

# Stop and save
playwright-cli -s=task video-stop
# → .webm in ~/.kiro/crew/playwright-snapshots/

# Convert to mp4
ffmpeg -i video.webm -c:v libx264 video.mp4
```

## Troubleshooting

1. **Page errors**: `playwright-cli console error`
2. **Network failures**: Set up response listener (see SKILL.md)
3. **Element not responding**: Check visibility with `evaluate`
4. **Trace (last resort)**: `tracing-start` → actions → `tracing-stop`

⚠️ Traces contain credentials — save to scratch, delete after analysis.

## Limitations

- Agent's shell has no `$DISPLAY` — works via loopback only
- Chrome restart changes the UUID — reconnect needed
- Extension popups (Jam, etc.) are outside CDP

## License

MIT

## Related

- [playwright-cli](https://github.com/anthropics/anthropic-tools) — The underlying CLI
- [Kiro Crew](https://kiro.dev) — Autonomous agent platform
