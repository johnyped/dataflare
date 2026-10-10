# Development with Mock License Server

The app gates one feature behind license activation: the free tier allows **2 connections**, an activated license allows unlimited. All other features are available regardless.

To develop or test with all features unlocked, run the app against a local mock of the license API instead of `https://api.dataflare.app`.

## What the mock does

`scripts/mock-license.mjs` is a zero-dependency mock of the license API:

| Endpoint | Behavior |
|---|---|
| `POST /license/activate` | Always succeeds, returns a dev token |
| `GET /license/verify` | `status: true` only for keys starting with `dev` |

The mock server runs on `http://127.0.0.1:9123` (override with `MOCK_LICENSE_PORT`).

The frontend reads the API base URL from `VITE_LICENSE_API_URL` (`src-web/utils/license.ts`), falling back to the real API when unset — **production builds are unaffected**.

## Prerequisites

1. **Rust** — required to build the Tauri backend. Install once:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
   source "$HOME/.cargo/env"   # or open a new terminal
   ```

   (Add `source "$HOME/.cargo/env"` to `~/.zshrc` to make it permanent.)

2. **Node + pnpm** — the project prefers Node 26; older versions work but print an engine warning.

3. **Working macOS toolchain** — `aws-lc-sys` compiles C and links test binaries at build time. If you see `ld: tapi error: malformed file ... .tbd: unknown architecture`, your default SDK is corrupt. `pnpm dev:mock` detects this and automatically falls back to a working Xcode SDK; the permanent fix is reinstalling Command Line Tools (`sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`).

## Quick start

```bash
pnpm dev:mock
```

One command does everything:

1. Starts the mock license server in the background
2. Starts the app (`tauri dev`) with `VITE_LICENSE_API_URL=http://127.0.0.1:9123`
3. Kills the mock server when the app exits

### Manual (two terminals)

```bash
# Terminal 1
pnpm dev:mock-license

# Terminal 2
VITE_LICENSE_API_URL=http://127.0.0.1:9123 pnpm dev
```

Windows PowerShell:

```powershell
$env:VITE_LICENSE_API_URL = "http://127.0.0.1:9123"
pnpm dev
```

## Activating

1. Launch the app and open the **Activate** window
2. Enter a key starting with `dev` (e.g. `dev`)
3. The mock returns a token, it is stored in the keychain, and unlimited connections are enabled

The license persists in the keychain and is re-verified against the mock on each launch. If the mock server is not running, verification fails and the app falls back to the 2-connection free tier (same behavior as offline).

To reset, delete the keychain entry `license` or deactivate in the app.

## Notes

- `pnpm dev` runs `tauri dev --no-watch` — restart the script after Rust or frontend changes that don't hot-reload.
- The first run compiles the Rust workspace and can take several minutes.
- If `pnpm` is not on PATH, the scripts fall back to `corepack pnpm`.
