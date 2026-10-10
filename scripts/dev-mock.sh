#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v cargo >/dev/null 2>&1; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi
if ! command -v cargo >/dev/null 2>&1; then
    echo "Rust is not installed. Install it first:" >&2
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
    exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
    if command -v corepack >/dev/null 2>&1; then
        PNPM="corepack pnpm"
    else
        echo "Neither pnpm nor corepack is available. Install pnpm:" >&2
        echo "  npm install -g pnpm   # or: brew install pnpm" >&2
        exit 1
    fi
else
    PNPM="pnpm"
fi

if ! command -v node >/dev/null 2>&1; then
    echo "Node.js is not available. Install it first:" >&2
    echo "  brew install node" >&2
    exit 1
fi

if [ ! -d node_modules ]; then
    $PNPM install
fi

port="${MOCK_LICENSE_PORT:-9123}"
export MOCK_LICENSE_PORT="$port"

probe=$(mktemp -d)
mock_pid=""

port_is_listening() {
    (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null
}

cleanup() {
    trap - EXIT
    if [ -n "$mock_pid" ]; then
        kill "$mock_pid" 2>/dev/null || true
        wait "$mock_pid" 2>/dev/null || true
    fi
    rm -rf "$probe"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

printf 'int main(void){return 0;}\n' > "$probe/t.c"
if ! clang "$probe/t.c" -o "$probe/t" >/dev/null 2>&1; then
    for app in /Applications/Xcode*.app; do
        sdk="$app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
        if [ -f "$sdk/usr/lib/libSystem.tbd" ] && \
            SDKROOT="$sdk" clang "$probe/t.c" -o "$probe/t" >/dev/null 2>&1; then
            echo "Default SDK is broken; using $sdk"
            export SDKROOT="$sdk"
            break
        fi
    done
fi

if command -v lsof >/dev/null 2>&1 && port_is_listening; then
    for stale in $(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null); do
        if ps -p "$stale" -o args= 2>/dev/null | grep -q 'mock-license\.mjs'; then
            echo "Killing stale mock license server (pid $stale) on port $port"
            kill "$stale" 2>/dev/null || true
        else
            echo "Port $port is already in use by pid $stale:" >&2
            ps -p "$stale" -o args= >&2
            echo "Stop that process, or set MOCK_LICENSE_PORT to a free port." >&2
            exit 1
        fi
    done
    for _ in $(seq 1 20); do
        port_is_listening || break
        sleep 0.25
    done
    if port_is_listening; then
        echo "Port $port is still in use after killing the stale mock license server." >&2
        exit 1
    fi
fi

node scripts/mock-license.mjs &
mock_pid=$!

for _ in $(seq 1 40); do
    if port_is_listening; then
        break
    fi
    if ! kill -0 "$mock_pid" 2>/dev/null; then
        echo "Mock license server failed to start" >&2
        exit 1
    fi
    sleep 0.25
done

if ! port_is_listening; then
    echo "Mock license server did not become ready on port $port" >&2
    exit 1
fi

echo "Mock license API running on http://127.0.0.1:$port"
VITE_LICENSE_API_URL="http://127.0.0.1:$port" $PNPM dev
