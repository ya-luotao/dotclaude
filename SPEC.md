# dotclaude behavior spec

This file states the promises `dotclaude` makes. Changing behavior described
here is a breaking change: update this spec and `tests/run` in the same commit,
deliberately. Tests reference sections by anchor (e.g. `S2`).

## S1. Profile model

- The **`default` profile** is the user's pre-existing Claude Code login. It is
  represented by **not setting `CLAUDE_CONFIG_DIR` at all**. Rationale
  (verified experimentally, Claude Code 2.1.252): with `CLAUDE_CONFIG_DIR` set,
  Claude Code reads/writes `.claude.json` *inside* that directory; with it
  unset, config lives at `~/.claude.json`. Setting `CLAUDE_CONFIG_DIR=~/.claude`
  therefore breaks the default login lookup. dotclaude must never launch the
  default profile with the variable set.
- **Named profiles** live at `$DOTCLAUDE_HOME/profiles/<name>`
  (`DOTCLAUDE_HOME` defaults to `~/.dotclaude`). A profile is activated by
  launching claude with `CLAUDE_CONFIG_DIR` pointing at its directory.
- Profile names match `[A-Za-z0-9_-]+`. `default` is reserved.

## S2. Resolution order (bare `claude` via the shell wrapper, and `current`)

Highest to lowest:

1. Explicitly set `CLAUDE_CONFIG_DIR` — never overridden.
2. Project binding: nearest `.dotclaude` file walking up from `$PWD`.
3. Global route: `$DOTCLAUDE_HOME/current`.
4. `default`.

A binding or route naming `default` short-circuits to the default login (env
var left unset). A binding or route naming a **missing** profile is an error
(wrapper exits 1 with a message naming the source file) — it must not silently
fall through to another account.

## S3. `setup <name>` guards

- Refuses `default` (would touch the real `~/.claude` login).
- Refuses a name whose profile directory already exists.
- Refuses invalid names (S1).
- On success: creates the directory, then launches claude with
  `CLAUDE_CONFIG_DIR` set to it so the user can `/login`.

## S4. `run <name> [args...]`

- Named profile: exec claude with `CLAUDE_CONFIG_DIR=<profile dir>`.
- `run default`: exec claude with `CLAUDE_CONFIG_DIR` **unset** (S1), even if
  it was set in the environment.
- Unknown profile: error, exit non-zero.
- All extra args pass through to claude unchanged.

## S5. `use` — global route

- `use <name>`: validates the profile exists, then writes its name to
  `$DOTCLAUDE_HOME/current`.
- `use` (no arg): prints the routed profile name, or a message that no route
  is set.
- `use default`: removes the route file.
- `doctor` flags a route naming a missing profile as a failure.

## S6. `bind <name> [dir]` / `unbind [dir]`

- `bind` validates the profile exists and writes its name as the single line
  of `<dir>/.dotclaude` (default: `$PWD`).
- `unbind` removes `<dir>/.dotclaude` only; bindings in parent directories are
  never touched. Missing file: prints a notice, exits 0.

## S7. `share` / `unshare` — config sharing

- Shareable items are a **hardcoded whitelist**: `agents`, `skills`,
  `commands`, `CLAUDE.md`. Requesting anything else is an error — in
  particular `.credentials.json`, `.claude.json`, `projects`, `history.jsonl`,
  `todos`, `sessions` must never become shareable, because sharing them breaks
  account isolation.
- `share` symlinks items from `~/.claude/<item>` into the profile. A source
  that doesn't exist is skipped with a notice. An existing non-symlink
  destination is preserved as `<item>.bak` before linking.
- `share default` is an error (default is the share source).
- `unshare` removes only symlinks and restores `<item>.bak` if present; a
  non-symlink destination is never deleted.

## S8. `clean <name> [--days N] [--force]`

- **Dry-run is the default.** Without `--force`, nothing is deleted; the
  output says what would be deleted.
- `--force` deletes only `*.jsonl` files under `<profile>/projects` strictly
  older than N days (default 30). Newer transcripts and non-jsonl files are
  untouched.
- Non-numeric `--days` is an error.

## S9. Introspection: `list`, `current`, `doctor`, `du`

- `list` shows every profile with the logged-in account read from the
  profile's `.claude.json` (`oauthAccount.emailAddress` / `organizationName`),
  or `not logged in` when absent. JSON parsing uses `jq` when available,
  falling back to `python3`; with neither, account shows as unknown — never an
  error.
- `current` names the active profile and why (env / binding / route / none).
- `doctor` warns when `ANTHROPIC_API_KEY` is set (it overrides `/login` for
  every profile) and fails on dangling share symlinks or a broken global route.

## S10. Shell wrapper scope

`shellenv` emits a `claude()` function implementing S2 plus
`DOTCLAUDE_WRAPPER=1` and an optional alias. It must call `command claude`
(no recursion) and must work in both bash and zsh. **Only interactive shells
that sourced it are affected**: scripts, herdr panes, and CI invoke the binary
directly and get the default account unless they use `dotclaude run` or set
`CLAUDE_CONFIG_DIR` themselves.

## S11. Known quirks (documented as-is, not promises)

- `current` with `CLAUDE_CONFIG_DIR` pointing outside `$DOTCLAUDE_HOME/profiles`
  prints the raw path instead of a profile name; `list`'s `*` marker only
  matches real profile names.
- `unbind` on a directory without a `.dotclaude` file exits 0 (notice only).

## S12. Self-describing help

- The command list shown by `help` is rendered from a single command table in
  the script — the one source of truth. Every listed command is dispatchable,
  and every command with a `help` topic appears in the list.
- `help <command>` prints a usage line, the one-line summary, and detailed
  notes/examples for that command. `<command> --help` (or `-h`, as the first
  argument) is equivalent and never executes the command.
- `help <unknown>` is an error (exit non-zero).
