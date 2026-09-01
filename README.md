# dotclaude

Run multiple Claude Code accounts (e.g. personal + team) on one machine, without
them stepping on each other — plus a few chores that come with that setup.

Claude Code has no built-in account switcher. Its documented isolation mechanism
is `CLAUDE_CONFIG_DIR`: each config directory gets its own credentials, settings,
sessions, and (on macOS) its own Keychain entry. `dotclaude` wraps that mechanism
into profiles.

## Disclaimer

This is a personal tool, provided **as is**, without warranty of any kind. It
is not affiliated with or endorsed by Anthropic. It only arranges Claude Code's
own documented `CLAUDE_CONFIG_DIR` mechanism; whether running multiple accounts
is appropriate in your situation is on you — make sure your usage complies with
[Anthropic's terms of service](https://www.anthropic.com/legal/consumer-terms)
and your organization's policies (e.g. don't use it to circumvent usage limits
or seat licensing). The author accepts no responsibility for misuse or for any
damage arising from use of this tool.

## Install

```sh
git clone https://github.com/ya-luotao/dotclaude ~/space/dotclaude
~/space/dotclaude/install.sh
```

Then add to `~/.zshrc` (pick any alias — `dc`, `dcl`, or none):

```sh
eval "$(dotclaude shellenv --alias dc)"
```

## Concepts

- **`default` profile** — your existing login. It is represented by *not* setting
  `CLAUDE_CONFIG_DIR` at all (config lives at `~/.claude` + `~/.claude.json`).
  Do **not** set `CLAUDE_CONFIG_DIR=~/.claude` manually: with the env var set,
  Claude Code looks for `.claude.json` *inside* the directory, which is not where
  the default login keeps it — you'd look logged out.
- **Named profiles** — live at `~/.dotclaude/profiles/<name>`, activated by
  setting `CLAUDE_CONFIG_DIR` to that path.

## Usage

```sh
dotclaude setup team          # create profile "team", opens claude to /login
dotclaude list                # profiles + which account each is logged into
dotclaude run team            # launch claude as "team" (any extra args pass through)
dotclaude run default         # launch claude as your original login
dotclaude use team            # route bare `claude` to "team" globally
dotclaude current             # which profile applies right here
```

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

> **Limitation:** anything that invokes the `claude` *binary* directly — scripts,
> herdr panes, CI, other tools — bypasses the shell function and gets the default
> account. For those, use `dotclaude run <name>` or set `CLAUDE_CONFIG_DIR`
> explicitly.

### Sharing config between profiles

Your agents, skills, commands, and global `CLAUDE.md` are usually
account-independent. Share them from `~/.claude` into a profile via symlinks:

```sh
dotclaude share team                      # links agents/ skills/ commands/ CLAUDE.md
dotclaude share team agents CLAUDE.md     # or pick specific items
dotclaude unshare team                    # remove links (restores .bak backups)
```

Only those four items are shared by default. Credentials, history, and
`.claude.json` are hardcoded as never-shareable — sharing them would break
account isolation (see FAQ).

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
(`--resume`/`--continue`), project memory included. Two things to know:

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
unavailable (SSH, containers).

## Development

Behavior promises live in [SPEC.md](SPEC.md); the test suite enforces them:

```sh
tests/run
```

Zero dependencies — each test runs in a hermetic sandbox (fresh `HOME`,
fake `claude` binary, minimal `PATH`), so it never touches your real login
or sessions.

## Uninstall

```sh
rm ~/.local/bin/dotclaude
# per-profile data stays in ~/.dotclaude/profiles — delete manually if wanted
```
