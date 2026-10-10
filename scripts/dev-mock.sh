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

if [ ! -d node_modules ]; then
    $PNPM install
fi

probe=$(mktemp -d)
mock_pid=""
cleanup() {
    if [ -n "$mock_pid" ]; then
        kill "$mock_pid" 2>/dev/null
    fi
    rm -rf "$probe"
}
trap cleanup EXIT
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

$PNPM dev:mock-license &
mock_pid=$!

sleep 1
if ! kill -0 "$mock_pid" 2>/dev/null; then
    echo "Mock license server failed to start" >&2
    exit 1
fi

echo "Mock license API running on http://127.0.0.1:9123"
VITE_LICENSE_API_URL=http://127.0.0.1:9123 $PNPM dev
