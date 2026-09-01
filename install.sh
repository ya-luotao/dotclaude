#!/usr/bin/env bash
# Install dotclaude: symlink bin/dotclaude into ~/.local/bin.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${DOTCLAUDE_BIN_DIR:-$HOME/.local/bin}"

mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/bin/dotclaude" "$BIN_DIR/dotclaude"
chmod +x "$REPO_DIR/bin/dotclaude"

echo "Installed: $BIN_DIR/dotclaude -> $REPO_DIR/bin/dotclaude"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "NOTE: $BIN_DIR is not in your PATH — add it to your shell rc." ;;
esac

cat <<'EOF'

Next, add shell integration to ~/.zshrc (enables per-project bindings
and a short alias — pick any alias you like, e.g. dc or dcl):

  eval "$(dotclaude shellenv --alias dc)"

Then create your second profile:

  dotclaude setup team
EOF
