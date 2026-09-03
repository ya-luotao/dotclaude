# dotclaude

[![CI](https://github.com/ya-luotao/dotclaude/actions/workflows/ci.yml/badge.svg)](https://github.com/ya-luotao/dotclaude/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ya-luotao/dotclaude?display_name=tag)](https://github.com/ya-luotao/dotclaude/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run multiple Claude Code accounts (personal + team, say) on one machine without
them stepping on each other — plus the chores that come with that setup.

Claude Code has no built-in account switcher. Its documented isolation
mechanism is `CLAUDE_CONFIG_DIR`: each config directory gets its own
credentials, settings, sessions and (on macOS) its own Keychain entry.
dotclaude wraps that mechanism into **profiles**. It is one dependency-free
shell script with a [behavior spec](SPEC.md) and a hermetic test suite.

```sh
dotclaude setup team          # create profile "team", log in once
dotclaude run team            # launch claude as "team"
dotclaude bind team           # in a repo: bare `claude` here is now "team"
dotclaude share team          # reuse your agents, skills, settings, plugins
dotclaude list                # who is logged in where
```

## Disclaimer

This is a personal tool, provided **as is**, without warranty of any kind. It
is not affiliated with or endorsed by Anthropic. It only arranges Claude Code's
own documented `CLAUDE_CONFIG_DIR` mechanism; whether running multiple accounts
is appropriate in your situation is on you — make sure your usage complies with
[Anthropic's terms of service](https://www.anthropic.com/legal/consumer-terms)
and your organization's policies (e.g. don't use it to circumvent usage limits
or seat licensing). The author accepts no responsibility for misuse or for any
damage arising from use of this tool.

## Requirements

- macOS or Linux, with bash 3.2 or newer (macOS's stock `/bin/bash` is fine).
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) on your `PATH`
  as `claude`.
- Optional: `jq` or `python3`. They read Claude Code's JSON files for the
  account shown by `list`, the `usage` and `keep` commands, plugin counts in
  `items`, and `doctor`'s retention check. Without either, those degrade
  (no account column, `usage`/`keep` refuse) and everything else works.
- Shell integration (per-project bindings, global routing) supports zsh and
  bash. In other shells use `dotclaude run <name>`.

## Install

**Homebrew** (macOS or Linux):

```sh
brew tap ya-luotao/dotclaude https://github.com/ya-luotao/dotclaude
brew install dotclaude
```

**Installer script** — downloads the latest [release](https://github.com/ya-luotao/dotclaude/releases),
verifies its SHA-256 against the published `SHA256SUMS`, and installs to
`~/.local/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/ya-luotao/dotclaude/main/install.sh | sh
```

Pin a version with `DOTCLAUDE_VERSION=v0.10.0` (or `... | sh -s -- --version v0.10.0`),
change the location with `DOTCLAUDE_BIN_DIR`, and pass `--uninstall` to remove it.

**From source** — the checkout is symlinked, so `git pull` updates it:

```sh
git clone https://github.com/ya-luotao/dotclaude.git
cd dotclaude && ./install.sh
```

Whichever way you installed, add the shell integration to `~/.zshrc` (or
`~/.bashrc`). It defines a `claude()` wrapper that applies bindings and routes,
plus an optional short alias:

```sh
eval "$(dotclaude shellenv --alias dc)"
```

## Concepts

- **`default` profile** — your existing login. It is represented by *not*
  setting `CLAUDE_CONFIG_DIR` at all (config lives at `~/.claude` +
  `~/.claude.json`). Do **not** set `CLAUDE_CONFIG_DIR=~/.claude` manually:
  with the env var set, Claude Code looks for `.claude.json` *inside* the
  directory, which is not where the default login keeps it — you'd look
  logged out.
- **Named profiles** — live at `~/.dotclaude/profiles/<name>`, activated by
  setting `CLAUDE_CONFIG_DIR` to that path.

## Commands

| Command | What it does |
| --- | --- |
| `setup <name>` | Create a profile and open claude in it to `/login` |
| `run <name> [args...]` | Launch claude as a profile (`default` = your original login) |
| `use [name\|default]` | Route bare `claude` to a profile globally; no arg shows, `default` clears |
| `list` | Profiles with the account each is logged into |
| `current` | Which profile applies in this directory, and why |
| `bind <name> [dir]` / `unbind [dir]` | Per-project binding via a `.dotclaude` file |
| `share <name> [items...]` / `unshare` | Symlink config from `~/.claude` into a profile |
| `items [name] [--names]` | What config each profile has, and what is shared |
| `doctor` | Common multi-account pitfalls |
| `usage [name]` | Cached 5h / weekly rate-limit windows per profile |
| `du` | Disk usage per profile |
| `clean <name> [--days N] [--force]` | Delete old session transcripts (dry-run by default) |
| `keep <name> [--days N]` | Stop Claude Code from auto-deleting a profile's sessions |
| `shellenv [--alias NAME]` | Print the shell integration |
| `help [command]` | Help, per command too (`dotclaude <command> --help`) |

`dotclaude help <command>` has the details and examples for each.

## Usage

### Global routing

Make bare `claude` use a profile everywhere, not just in bound projects:

```sh
dotclaude use team            # bare `claude` now runs as "team" globally
dotclaude use                 # show the current global route
dotclaude use default         # clear it — back to your original login
```

Resolution order for bare `claude` (via the shell wrapper):
explicit `CLAUDE_CONFIG_DIR` > project `.dotclaude` binding > global route > default.

### Per-project binding

```sh
cd ~/work/company-repo
dotclaude bind team           # writes .dotclaude (add it to .gitignore)
claude                        # now automatically uses the team profile
```

Binding works through the `claude()` shell wrapper from `shellenv`: it walks up
from `$PWD` looking for a `.dotclaude` file. An explicitly set
`CLAUDE_CONFIG_DIR` always wins over a binding.

> **Limitation:** anything that invokes the `claude` *binary* directly —
> scripts, editor integrations, CI, other tools — bypasses the shell function
> and gets the default account. For those, use `dotclaude run <name>` or set
> `CLAUDE_CONFIG_DIR` explicitly.

### Sharing config between profiles

Your agents, skills, commands, plugins, hooks, settings, keybindings, and
global `CLAUDE.md` are usually account-independent. Share them from
`~/.claude` into a profile via symlinks:

```sh
dotclaude share team                      # links agents/ skills/ commands/ plugins/ hooks/
                                          #   settings.json keybindings.json CLAUDE.md
dotclaude share team agents CLAUDE.md     # or pick specific items
dotclaude unshare team                    # remove links (restores .bak backups)
```

Those are all the config items, and all are shared by default. Credentials,
history, `.claude.json` and `settings.local.json` are hardcoded as
never-shareable — the first three would break account isolation, the last
exists precisely to hold per-profile overrides (see FAQ).

`settings.json` carries model, theme, permissions, hook configuration,
which plugins are enabled, and session retention, so sharing it means one
set of preferences everywhere: change a setting in any profile and all of
them follow. To keep settings per-profile, name the items you want instead:

```sh
dotclaude share team agents skills commands plugins hooks CLAUDE.md
```

`plugins/` is the whole plugin store — marketplaces, installed plugins, and
their cache, typically hundreds of megabytes, so sharing it also means one
copy instead of one per profile. The trade-off: installing or removing a
plugin (or adding a marketplace) in one profile does it for every profile
sharing the store. Which plugins are *enabled* lives in `settings.json`, so
it is shared exactly when that file is; profiles that keep their own
settings can run different subsets. A profile that already had plugins
keeps its own copy at `plugins.bak` (not merged), and `unshare` puts it
back.

To see what any profile actually has:

```sh
dotclaude items                     # every profile: agents/skills/commands/plugins counts
dotclaude items team --names        # spell out the names, marking disabled plugins
```

```
default  /Users/you/.claude
  agents            7
  skills            45
  commands          3
  plugins           34 installed, 12 on
  hooks             9
  settings.json     present
  keybindings.json  -
  CLAUDE.md         present

team  /Users/you/.dotclaude/profiles/team
  agents            7                      shared
  skills            45                     shared
  commands          3                      shared
  plugins           34 installed, 12 on    shared
  hooks             9                      shared
  settings.json     present                shared
  keybindings.json  -
  CLAUDE.md         present                shared
```

### Sharing sessions between profiles (opt-in)

Session transcripts (`projects/`) can be shared too, but only by naming the
item explicitly — it merges session history across accounts, so it never
happens implicitly:

```sh
dotclaude share team projects     # merge team's transcripts into ~/.claude/projects,
                                  # keep the original as projects.bak, then symlink
dotclaude unshare team projects   # restore pre-share transcripts; transcripts
                                  # created while shared stay in ~/.claude/projects
```

Afterwards every sharing profile sees and resumes the same sessions
(`--resume`/`--continue`), project memory included. Three things to know:

- **Set a retention horizon on every participating profile**
  (`dotclaude keep <name>`, default profile included) — otherwise one
  profile's 30-day default cleanup prunes the shared store for everyone.
  `doctor` warns about this.
- `clean` refuses a sessions-sharing profile; prune the shared store
  deliberately with `dotclaude clean default`.
- Run `share <name> projects` while no `claude` is running in that profile —
  a transcript written mid-share can end up in `projects.bak` instead of the
  shared store.

Prompt history, `todos/`, and per-project trust/settings stay per-profile —
only the transcripts and project memory are shared. Whether merging session
history across accounts is appropriate in your situation is on you (see the
disclaimer at the top).

### Chores

```sh
dotclaude doctor                    # ANTHROPIC_API_KEY pollution, login status,
                                    # dangling share links, wrapper active?
dotclaude du                        # disk usage per profile (sessions get big)
dotclaude clean team --days 60      # dry-run: what would be deleted
dotclaude clean team --days 60 --force   # actually delete old transcripts
dotclaude usage                     # cached 5h/weekly rate-limit windows per profile
dotclaude items                     # what config each profile has, and what's shared
```

## Verify isolation once (recommended)

Two-account credential isolation via `CLAUDE_CONFIG_DIR` is how the credential
system behaves, but multi-account is not an officially documented workflow. After
setting up your second profile, verify once:

1. `dotclaude run team` → `/status` shows the team account.
2. `dotclaude run default` → `/status` still shows your personal account.

If step 2 ever shows the team account, isolation broke (e.g. a Claude Code
update changed Keychain behavior) — please open an issue.

## FAQ

**Can sessions live in one shared place across profiles?**
Yes, as an explicit opt-in: `dotclaude share <name> projects` (see above).
There is no official knob to relocate sessions separately from the config
dir, so this symlinks `projects/` into the shared store. Transcripts are
UUID-named jsonl files, so concurrent profiles don't collide on writes; the
real hazard is retention (one profile's cleanup pruning everyone's
transcripts), which `keep` + `doctor` cover. If you only want to move a
single conversation across accounts, `/export` still works.

**Why does `doctor` warn about `ANTHROPIC_API_KEY`?**
If set, it overrides `/login` credentials for every profile — all usage bills
to that key regardless of which profile you launch.

**Where does a profile's login live?**
macOS Keychain (appears to be keyed per config dir — run the verification
above once to confirm on your machine), falling back to
`<profile>/.credentials.json` (mode 0600, plaintext) when the Keychain is
unavailable (Linux, SSH, containers).

**How do I keep per-profile settings while sharing `settings.json`?**
Put them in the profile's `settings.local.json` — it is never shared and
Claude Code layers it over `settings.json`.

## Update and uninstall

| Installed via | Update | Uninstall |
| --- | --- | --- |
| Homebrew | `brew upgrade dotclaude` | `brew uninstall dotclaude` |
| Installer script | re-run the `curl ... \| sh` line | `curl ... \| sh -s -- --uninstall` |
| Source checkout | `git pull` | `./install.sh --uninstall` |

Uninstalling removes only the command. Profiles, logins and sessions stay in
`~/.dotclaude`; delete that directory if you want them gone, and drop the
`shellenv` line from your shell rc.

## Development

Behavior promises live in [SPEC.md](SPEC.md); `tests/run` enforces them and
`tests/installer` covers `install.sh`. Every test runs in a hermetic sandbox (fresh `HOME`, fake `claude` binary,
minimal `PATH`), so it never touches your real login or sessions.

```sh
tests/run          # behavior suite
tests/installer    # install.sh: checkout mode, uninstall, verified download
shellcheck -S warning bin/dotclaude install.sh tests/run tests/installer
```

CI runs the same on macOS (including stock `/bin/bash` 3.2) and Ubuntu.

**Releasing.** Bump `VERSION` in `bin/dotclaude`, add a `## [x.y.z]` section
to [CHANGELOG.md](CHANGELOG.md), commit, then tag and push:

```sh
git tag -a v0.10.0 -m "v0.10.0" && git push origin main v0.10.0
```

The release workflow re-runs the tests, publishes a GitHub release (the script
plus `SHA256SUMS`, which the installer verifies), and commits the updated
`Formula/dotclaude.rb` so Homebrew users get the new version.

## License

[MIT](LICENSE).
