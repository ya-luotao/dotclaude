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
  `commands`, `plugins`, `hooks`, `settings.json`, `keybindings.json`,
  `CLAUDE.md`, plus `projects` (session transcripts) as a **strictly
  opt-in** item — in the whitelist but never in the default set, so
  `share <name>` without items links every config item and nothing else.
  Requesting anything else is an error — in particular `.credentials.json`,
  `.claude.json`, `history.jsonl`, `todos` must never become shareable,
  because sharing them breaks account isolation. `settings.local.json` is
  not shareable either: it exists to hold per-machine, per-profile
  overrides. (Sharing `projects` merges
  session history across accounts deliberately; the caveats are printed and
  documented, and the ToS note in the README applies.)
- `share` symlinks items from `~/.claude/<item>` into the profile. A source
  that doesn't exist is skipped with a notice — except `projects`, whose
  source directory is created. An existing non-symlink destination is
  preserved as `<item>.bak` before linking; if a `<item>.bak` is already
  there, `share` refuses that item rather than moving a directory inside its
  own stale backup or discarding an older file backup.
- `plugins` (the whole plugin store: marketplaces, installed plugins, their
  cache) is part of the **default** set: what is installed is machine-level
  rather than account-level, and the store runs to hundreds of megabytes.
  The consequence, documented in `help share`, is that installing or
  removing a plugin (or adding a marketplace) in one sharing profile does it
  for all of them. Plugin **enablement** (`enabledPlugins`) lives in
  `settings.json`, so it is shared exactly when `settings.json` is: with
  the default set both are linked and every profile enables the same
  plugins; a profile that keeps its own `settings.json` can enable a
  different subset. Unlike `projects`, a profile's existing `plugins`
  directory is **not** merged into the shared store — it is kept whole at
  `plugins.bak` and restored by `unshare`.
- `settings.json` is part of the **default** set: model, theme,
  permissions, hook configuration, `enabledPlugins` and `cleanupPeriodDays`
  are machine-level preferences, not account-level ones, and the user wants
  one set of them everywhere. A profile's own `settings.json` is kept as
  `settings.json.bak`, never merged. Because dotclaude itself edits this
  file (`keep`, S14), it must write **through** the symlink: replacing the
  link with a private copy would silently unshare the item.
- Sharing `projects` first **merges** the profile's existing transcripts
  into `~/.claude/projects`: files already present in the shared store are
  never overwritten, and the merge completes before anything moves aside, so
  a failed merge leaves the profile untouched. The original directory is
  kept as `projects.bak`, then the symlink is created. When the profile's
  `cleanupPeriodDays` is unset, a notice suggests `keep` (S14): the 30-day
  default cleanup would prune the shared store (with neither `jq` nor
  `python3` the notice is skipped — the setting is unreadable).
- Sharing `projects` **refuses** two states rather than guessing: an existing
  `projects` symlink pointing anywhere but the shared store (removing it
  would silently drop those sessions from the profile, unmerged and
  unbacked), and an existing `projects.bak` (a second `mv` would nest into
  it and a later `unshare` would restore a corrupted tree). Both are errors
  naming the path; nothing is modified.
- `share default` is an error (default is the share source).
- `unshare` removes only symlinks and restores `<item>.bak` if present; a
  non-symlink destination is never deleted. Like `share`, `projects` must be
  named explicitly. Unsharing `projects` restores the pre-share transcripts
  only; transcripts created while shared remain in `~/.claude/projects`.

## S8. `clean <name> [--days N] [--force]`

- **Dry-run is the default.** Without `--force`, nothing is deleted; the
  output says what would be deleted.
- `--force` deletes only `*.jsonl` files under `<profile>/projects` strictly
  older than N days (default 30). Newer transcripts and non-jsonl files are
  untouched.
- A profile whose `projects` is a symlink (shared sessions, S7) is refused
  with an error — cleaning through the link would delete every profile's
  transcripts. The error points at `clean default`.
- `clean default` is supported and operates on `~/.claude/projects` — the
  deliberate way to prune the shared store.
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
- `doctor` reports profiles whose sessions are shared (`projects` symlinked
  to `~/.claude/projects`) — even for a profile that has never been launched
  (no `.claude.json`) — and warns — counted as a problem — when any
  participating profile (the default profile included) has no
  `cleanupPeriodDays` set, since its 30-day default cleanup would prune the
  shared store. With neither `jq` nor `python3` the check is skipped, never
  an error.
- `du` shows `shared` instead of a size in the SESSIONS column for a profile
  whose `projects` is a symlink.

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

## S13. `usage [name]` — cached rate-limit windows

- Shows, per profile: the 5-hour session window, the weekly window, and any
  per-model weekly limits — utilization % with reset time — plus the cache age.
- Data source is **Claude Code's own local cache**
  (`cachedUsageUtilization` in the profile's `.claude.json`). `usage` makes
  **no network requests and never touches credentials**. There is no official
  CLI or API for subscription window utilization (verified 2026-09-01); the
  cache format is undocumented and may change — parsing is best-effort: an
  unrecognized format degrades to missing rows or the no-data notice, never
  a crash.
- A profile without cached data gets a notice (exit 0); an unknown profile
  name is an error. Requires `jq` or `python3`.
- Unknown options are errors.

## S14. `keep <name> [--days N]` — session retention

- Sets `cleanupPeriodDays` (Claude Code's transcript retention setting;
  its default is 30) in the profile's `settings.json` — default value here
  is 999999, effectively disabling auto-cleanup.
- The merge is surgical: every other key in `settings.json` is preserved,
  and the file is created if missing. A failed merge leaves the original
  file untouched.
- A shared `settings.json` (a symlink, S7) is followed: the value lands in
  the real file and the symlink survives, so the setting applies to every
  profile sharing that file — and `keep` says so.
- `--days 0` is refused: a known Claude Code bug makes `cleanupPeriodDays: 0`
  disable transcript writing entirely rather than disabling cleanup.
- Non-numeric `--days` and unknown profiles are errors. Requires `jq` or
  `python3`.

## S15. `items [name] [--names]` — per-profile config inventory

- For each profile (all of them, or the one named), prints how much of each
  shareable config item it has: `agents`, `skills`, `commands` and `hooks`
  counts (hooks: files at any depth), plugins as `N installed, M on`, and
  whether `settings.json`, `keybindings.json` and a global `CLAUDE.md` are
  present — plus a state column per item.
- Counting rules: agents and commands are `*.md` files at any depth
  (commands nest legitimately — `commands/<dir>/<name>.md` is namespaced);
  a **skill** is exactly `skills/<name>/SKILL.md`, so a `SKILL.md` deeper
  inside a skill (a vendored checkout) is not counted as another skill.
  Counts follow share symlinks.
- State per item: nothing for the `default` profile (it is the share
  source), `shared` when the item symlinks to `~/.claude/<item>`,
  `shared (BROKEN LINK)` when that source is gone, `-> <target>` for a
  symlink pointing elsewhere, `own` for a real file or directory, and
  nothing when the item is absent.
- `N installed` comes from the profile's
  `plugins/installed_plugins.json`; `M on` from `enabledPlugins` in its
  `settings.json`. Profiles on one shared plugin store that keep their own
  `settings.json` legitimately show different `on` counts (S7).
- `--names` additionally spells out the skill, agent, command and plugin
  names, wrapped; a plugin that is installed but not enabled in that profile
  is suffixed `(off)`.
- Without `jq` or `python3` the plugin counts degrade to zero rather than
  erroring, matching `list` (S9). An unknown profile name and an unknown
  option are errors.
