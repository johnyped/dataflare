# Dev with Mock License — Quick Guide

One command runs the app against a local mock license server, with all features unlocked:

```bash
./run_dev.sh    # or: make run-dev
```

This wraps `scripts/dev-mock.sh`:

1. Starts the mock license server (`scripts/mock-license.mjs`) in the background on `http://127.0.0.1:9123`
2. Starts the app (`tauri dev --no-watch`) with `VITE_LICENSE_API_URL=http://127.0.0.1:9123`
3. Kills the mock server when the app exits

## What the mock does

| Endpoint | Behavior |
|---|---|
| `POST /license/activate` | Always succeeds, returns a dev token |
| `GET /license/verify` | `status: true` only for keys starting with `dev` |

- The free tier limits you to 2 connections; an activated license removes the limit.
- The frontend reads `VITE_LICENSE_API_URL`, falling back to the real API (`https://api.dataflare.app`) when unset — production builds are unaffected.

## Prerequisites

1. **Rust**

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
   source "$HOME/.cargo/env"   # or open a new terminal
   ```

2. **Node + pnpm** — the project prefers Node 26; older versions work but print an engine warning. Install pnpm once (Node 25+ no longer bundles corepack):

   ```bash
   npm install -g pnpm   # or: brew install pnpm
   ```

   If `pnpm` is not on PATH, the script falls back to `corepack pnpm` — but only when corepack exists; otherwise it exits with the install command above. Missing `node_modules` are installed automatically.

3. **Working macOS toolchain** — `aws-lc-sys` compiles C at build time. If you see `ld: tapi error: malformed file ... .tbd: unknown architecture`, the script automatically falls back to a working Xcode SDK. Permanent fix: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`.

## Activating

1. Launch the app and open the **Activate** window
2. Enter a key starting with `dev` (e.g. `dev`)
3. Unlimited connections are enabled

The license persists in the keychain and is re-verified against the mock on each launch. If the mock server is not running, verification fails and the app falls back to the 2-connection free tier (same as offline). To reset, delete the keychain entry `license` or deactivate in the app.

## Notes

- `pnpm dev` runs `tauri dev --no-watch` — restart after Rust or frontend changes that don't hot-reload.
- The first run compiles the Rust workspace and can take several minutes.
- Manual two-terminal setup: `pnpm dev:mock-license` in one terminal, `VITE_LICENSE_API_URL=http://127.0.0.1:9123 pnpm dev` in another.
- Full details: [docs/dev-mock-license.md](docs/dev-mock-license.md)
