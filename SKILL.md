# Browser Automation

> Drive the user's logged-in Chrome browser via CDP (Chrome DevTools Protocol) to automate
> web applications without requiring separate logins or API credentials.

## When to use

- Automate web apps the user is already logged into (Teams, Outlook, Jira web, internal tools)
- Read or send messages, scrape data, fill forms, navigate workflows
- Record video of browser interactions for demos or debugging
- When MCP tools or APIs are unavailable or insufficient

## Prerequisites (user setup, one time)

1. Open Chrome normally (no special flags)
2. Go to `chrome://inspect/#remote-debugging` and enable
3. Install the Playwright extension:
   https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm

That's it. The agent handles everything else.

## How it works

The agent connects to the user's running Chrome via CDP, opens tabs, and interacts with
pages using `playwright-cli`. The user's existing sessions (login cookies) are available.

```bash
# Connect to user's Chrome (agent does this automatically)
P=$HOME/.config/google-chrome/DevToolsActivePort
PORT=$(sed -n 1p "$P"); WS=$(sed -n 2p "$P")
playwright-cli attach --cdp="ws://127.0.0.1:${PORT}${WS}"

# Open a new tab (never navigate the user's existing tabs)
playwright-cli -s=<session> run-code "async (page) => { await page.evaluate(() => window.open('https://example.com', '_blank')); }"

# Interact
playwright-cli -s=<session> snapshot
playwright-cli -s=<session> click <ref>
playwright-cli -s=<session> fill <ref> "text"
playwright-cli -s=<session> screenshot
```

## Rules

### Navigation

- **`window.open`, never `tab-new` or `goto`** — `tab-new` opens in the dashboard window
  and covers the conversation. Always: `tab-select` to a tab in the target window →
  `run-code` with `window.open('URL', '_blank')`.
- **Never `close`** — use `detach` when done
- **Fresh snapshot before interacting** — refs die after navigation
- **Two windows**: dashboard (conversation) and work (Teams, etc.). New tabs always in
  the work window.

### Reading content

Priority (for any site):

1. `evaluate` + `innerText`/`innerHTML` → read text and data
2. `snapshot` → element refs and confirm state
3. `screenshot` → last resort, only for visual verification (layout, images)

```javascript
// Read page content
page.evaluate(() => document.querySelector('[data-tid="app-layout-area--main"]').innerText)
```

### Parallel sessions (chat × cron × sub-agent)

- The `playwright-cli` connection is **per-process**: crons and sub-agents don't inherit
  the chat's connection. New session connects via `tools/attach.sh`.
- All use the **same Chrome**: two sessions touching the same tab interfere. Rule: each
  process works in its own tab; local DB reads (IndexedDB) don't touch the screen and can
  run in parallel.
- Name sessions when multiple processes browse: `-s=<task-name>` on all commands for that
  process (or `PLAYWRIGHT_CLI_SESSION=<name>`).
- **Never** `close`, `close-all`, `kill-all`, or `delete-data` on the user's browser —
  closes windows and deletes logins. To exit, `detach`.

### Route interception — don't use on user's browser

`playwright-cli route "<pattern>" --status=…/--body=…` simulates responses or blocks
resources. Useful for testing in isolated sessions. On the user's Chrome **don't use**:
the rule applies to the entire tab and breaks Teams/ADM they're using. If essential,
remove immediately with `playwright-cli unroute`.

## Troubleshooting

Order (lightest to heaviest):

1. **Page JavaScript errors**: `playwright-cli console error`
2. **Failed requests**: set up a listener that prints only status + path (no headers/body
   which carry credentials):
   ```bash
   playwright-cli run-code "async page => { page.on('requestfailed', r => console.log('FAILED', r.method(), r.url().split('?')[0], r.failure()?.errorText)); page.on('response', r => { if (r.status() >= 400) console.log('HTTP', r.status(), r.url().split('?')[0]); }); }"
   ```
   Avoid `requests` / `request <n>` / `response-headers`: they show headers and body with
   tokens (require approval).
3. **Element doesn't respond to click**: check via `page.evaluate` if visible, disabled,
   or covered by another element (`document.elementFromPoint` at center of
   `getBoundingClientRect`).
4. **Wait for page to settle**: `page.waitForLoadState('networkidle')` or
   `locator.waitFor({ state: 'visible' })` inside `run-code`.
5. **Trace (last resort)**: `playwright-cli tracing-start` → reproduce → `tracing-stop`.
   Records DOM, network, and console for each step. ⚠️ On a logged-in browser the trace
   contains **tokens and cookies**: save only to `$KIROCREW_SCRATCH`, delete after
   analysis, never send to `trace.playwright.dev` or attach to tickets.

To catch **a specific API response** (e.g., Teams messages), instead of a listener:
```javascript
const r = await page.waitForResponse(u => u.url().includes('/messages'));
return await r.json();
```

## Video recording

Record browser interactions for demos, testing, or debugging.

```bash
# Start HD recording with animated cursor
playwright-cli -s=<session> video-start --size 1920x1080 --cursor

# Mark chapters
playwright-cli -s=<session> video-chapter "Opening menu X"

# Visually highlight each action (optional)
playwright-cli -s=<session> video-show-actions

# Stop and save
playwright-cli -s=<session> video-stop
# Generates .webm in ~/.kiro/crew/playwright-snapshots/
```

| Flag | Effect | Default |
|---|---|---|
| `--size 1920x1080` | Resolution | 800x800 (illegible text) |
| `--fps 30` | Frames per second | 25 |
| `--cursor` | Animated cursor + element highlight | No cursor |

- **Always** record at 1920x1080 — default makes text illegible.
- May generate multiple `.webm` segments; the main one is the largest.
- Deliver to user with `file_send` (download in dashboard).
- Convert to mp4/gif if needed: `ffmpeg -i video.webm -c:v libx264 video.mp4`

## App-specific patterns

### Microsoft Teams

```javascript
// Read chat content (what's loaded in DOM)
document.querySelector('[data-tid="app-layout-area--main"]').innerText

// Chat list items (stable IDs)
document.querySelectorAll('span[id^="title-chat-list-item_"]')

// Message editor
textbox: '[data-tid="app-layout-area--main"] [role="textbox"]'
send button: 'button[aria-label*="Send"]'

// Search in chat
Ctrl+F → type in searchbox → Enter

// @mention
Type '@Name' → wait for Suggestions listbox → click option
```

**Gotchas:**
- `mouse.wheel` doesn't scroll the chat: scroll is in an internal div, not body.
- Teams virtualizes messages: scrolling unloads old ones from DOM. `innerText` gets only
  the loaded buffer. For long history, use search (Find/global).
- Expanding folders may be needed to see all chat items.

### Reading without marking as read

Use local IndexedDB cache instead of opening chats:

```javascript
// Teams stores messages in IndexedDB: Teams:replychain-manager:…
// Store: replychains, key: [conversationId, replyChainId]
// Each record has messageMap with messages
```

This reads cached messages without marking them as read. Coverage depends on what the user
has previously opened in that browser.

## Limitations

- The agent's shell has no `$DISPLAY`. CDP connection works via loopback.
- If Chrome restarts, the UUID changes and the agent reconnects.
- Extension popups (like Jam) are outside CDP — can't automate those.

## Tools

| Script | Purpose |
|---|---|
| `tools/attach.sh` | Connect to user's Chrome, return session info |

## See also

- `web-browse` skill — higher-level browsing patterns
- `web-preview` skill — preview local dev servers
- `browser-auth` skill — logged-in session management
