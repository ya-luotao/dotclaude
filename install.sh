#!/bin/sh
# dotclaude installer — https://github.com/ya-luotao/dotclaude
#
#   From a checkout:     ./install.sh
#       symlinks bin/dotclaude into the bin dir, so `git pull` updates it
#   Without a checkout:  curl -fsSL https://raw.githubusercontent.com/ya-luotao/dotclaude/main/install.sh | sh
#       downloads the latest GitHub release and verifies its SHA-256
#   Uninstall:           ./install.sh --uninstall   (or: curl ... | sh -s -- --uninstall)
#
# Options (each also settable through the environment variable in brackets):
#   --bin-dir DIR    where to put the `dotclaude` command   [DOTCLAUDE_BIN_DIR, default ~/.local/bin]
#   --version TAG    release to download, e.g. v0.10.0     [DOTCLAUDE_VERSION, default: latest release]
#                    "main" downloads the unreleased tip of main (no checksum available)
#   --uninstall      remove the command; profiles under ~/.dotclaude are kept
set -eu

REPO="ya-luotao/dotclaude"
BIN_DIR="${DOTCLAUDE_BIN_DIR:-$HOME/.local/bin}"
VERSION="${DOTCLAUDE_VERSION:-latest}"
MODE=install
# Base URLs; overridable so tests/installer can point them at a local server.
RELEASES_URL="${DOTCLAUDE_RELEASES_URL:-https://github.com/$REPO/releases}"
RAW_URL="${DOTCLAUDE_RAW_URL:-https://raw.githubusercontent.com/$REPO}"

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
usage: install.sh [--bin-dir DIR] [--version TAG|main] [--uninstall]

  --bin-dir DIR    install location            (DOTCLAUDE_BIN_DIR, default ~/.local/bin)
  --version TAG    release to download         (DOTCLAUDE_VERSION, default latest; "main" = unreleased tip)
  --uninstall      remove the dotclaude command; ~/.dotclaude profiles are kept

Run from a git checkout, install.sh symlinks bin/dotclaude instead of downloading.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --bin-dir)   [ $# -ge 2 ] || die "--bin-dir needs a value"; BIN_DIR="$2"; shift 2 ;;
    --version)   [ $# -ge 2 ] || die "--version needs a value"; VERSION="$2"; shift 2 ;;
    --uninstall) MODE=uninstall; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           usage >&2; die "unknown option: $1" ;;
  esac
done

target="$BIN_DIR/dotclaude"

# Running from a checkout? $0 is the script path then; when piped into sh it
# is just "sh" (and a process substitution is not a regular file either).
checkout=""
if [ -f "$0" ]; then
  dir="$(cd "$(dirname "$0")" && pwd)"
  [ -f "$dir/bin/dotclaude" ] && checkout="$dir"
fi

if [ "$MODE" = uninstall ]; then
  if [ -L "$target" ] || [ -f "$target" ]; then
    case "$(head -n 2 "$target" 2>/dev/null)" in
      *dotclaude*) rm -f "$target"; say "Removed $target" ;;
      *) die "$target does not look like dotclaude — not removing it" ;;
    esac
  else
    say "Nothing installed at $target"
  fi
  say "Kept: ${DOTCLAUDE_HOME:-$HOME/.dotclaude} (profiles, logins, sessions) — delete it yourself if you want them gone."
  say "Also remove the 'eval \"\$(dotclaude shellenv ...)\"' line from your shell rc."
  exit 0
fi

mkdir -p "$BIN_DIR"

if [ -n "$checkout" ]; then
  [ -x "$checkout/bin/dotclaude" ] || chmod +x "$checkout/bin/dotclaude"
  ln -sf "$checkout/bin/dotclaude" "$target"
  say "Installed: $target -> $checkout/bin/dotclaude (symlink; git pull to update)"
else
  fetch() { # URL DEST
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
    else die "need curl or wget to download dotclaude"
    fi
  }
  sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    else die "need sha256sum or shasum to verify the download"
    fi
  }
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  if [ "$VERSION" = main ]; then
    url="$RAW_URL/main/bin/dotclaude"
    fetch "$url" "$tmp/dotclaude" || die "download failed: $url"
    say "Downloaded the unreleased tip of main (no checksum to verify against)"
  else
    if [ "$VERSION" = latest ]; then base="$RELEASES_URL/latest/download"
    else base="$RELEASES_URL/download/$VERSION"
    fi
    fetch "$base/dotclaude" "$tmp/dotclaude" \
      || die "download failed: $base/dotclaude (no such release? see https://github.com/$REPO/releases)"
    fetch "$base/SHA256SUMS" "$tmp/SHA256SUMS" || die "download failed: $base/SHA256SUMS"
    expected="$(awk '$2 == "dotclaude" || $2 == "*dotclaude" { print $1 }' "$tmp/SHA256SUMS")"
    [ -n "$expected" ] || die "SHA256SUMS has no entry for dotclaude"
    actual="$(sha256_of "$tmp/dotclaude")"
    [ "$actual" = "$expected" ] || die "checksum mismatch for dotclaude: expected $expected, got $actual"
    say "Verified SHA-256: $actual"
  fi

  head -n 2 "$tmp/dotclaude" | grep -q '^# dotclaude' || die "downloaded file is not the dotclaude script"
  chmod 755 "$tmp/dotclaude"
  mv -f "$tmp/dotclaude" "$target"
  say "Installed: $target ($("$target" version))"
fi

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say ""; say "NOTE: $BIN_DIR is not in your PATH — add it to your shell rc:"; say "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

cat <<'NEXT'

Next, enable shell integration — add to ~/.zshrc (or ~/.bashrc). It provides
per-project bindings, global routing, and an optional short alias:

  eval "$(dotclaude shellenv --alias dc)"

Then create your second profile and log in:

  dotclaude setup team
NEXT
