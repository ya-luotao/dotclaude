# Changelog

All notable changes to dotclaude are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/) (0.x: minor bumps may break).

The release workflow publishes the section for the tagged version as the
GitHub release notes, so every release needs its own `## [x.y.z]` heading.

## [Unreleased]

## [0.10.0] - 2026-09-03

### Added
- Distribution: GitHub Releases (script + `SHA256SUMS`), a Homebrew formula
  (`brew tap ya-luotao/dotclaude https://github.com/ya-luotao/dotclaude`),
  and a `curl | sh` installer that verifies the download's checksum.
- `install.sh --uninstall`, `--bin-dir`, `--version`; works from a checkout
  (symlink, as before) or without one (download a release).
- CI on macOS and Ubuntu: test suite, macOS `/bin/bash` 3.2, shellcheck,
  installer smoke test. Release workflow: tag `vX.Y.Z` → release + formula bump.
- MIT license file.

### Fixed
- Test suite is now portable to Linux (merged-`/usr` systems, root sandboxes).
- shellcheck-clean at warning level.

## [0.9.0] - 2026-09-03

### Added
- `items [name] [--names]`: per-profile inventory of agents, skills,
  commands, plugins and hooks, marking what is shared, own, or a broken link.
- Test: a failed `share <name> projects` merge leaves the profile untouched.

### Changed
- `share` defaults now cover every config item: `settings.json`, `hooks/`
  and `plugins/` join agents, skills, commands, keybindings and `CLAUDE.md`.
  `projects` stays opt-in.
- `keep` writes through a shared `settings.json` symlink instead of replacing
  it with a private copy.

### Removed
- `usage --timeline`.

## [0.7.0] - 2026-09-01

### Added
- `usage --timeline`: all accounts on one reset-time axis.

## [0.6.0] - 2026-09-01

### Added
- Opt-in session sharing: `share <name> projects` merges a profile's
  transcripts into `~/.claude/projects` and symlinks it; `unshare` restores
  the pre-share copy. `doctor`, `du` and `clean` are sessions-sharing aware.

## [0.5.0] - 2026-09-01

### Added
- `keep <name> [--days N]`: set `cleanupPeriodDays` so Claude Code stops
  auto-deleting a profile's transcripts.

## [0.4.0] - 2026-09-01

### Added
- `usage [name]`: cached 5h / weekly rate-limit windows per profile, read
  from Claude Code's own local cache (no network, no credentials).

## [0.3.0] - 2026-09-01

### Added
- Self-describing help: `help <command>` and `<command> --help`, rendered
  from one command table that the tests check against the dispatcher.
- Disclaimer in the README.

## [0.2.0] - 2026-09-01

### Added
- Global routing: `use <name>` makes bare `claude` run as a profile everywhere.
- Behavior spec (`SPEC.md`) and hermetic test suite (`tests/run`).

## [0.1.0] - 2026-09-01

### Added
- Initial release: `setup`, `run`, `list`, `current`, `bind`/`unbind`,
  `share`/`unshare`, `doctor`, `du`, `clean`, `shellenv`.

[Unreleased]: https://github.com/ya-luotao/dotclaude/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/ya-luotao/dotclaude/releases/tag/v0.10.0
[0.9.0]: https://github.com/ya-luotao/dotclaude/compare/0b60801...806a7a2
[0.7.0]: https://github.com/ya-luotao/dotclaude/compare/0c40927...0b60801
[0.6.0]: https://github.com/ya-luotao/dotclaude/compare/36de388...0c40927
[0.5.0]: https://github.com/ya-luotao/dotclaude/compare/3944815...36de388
[0.4.0]: https://github.com/ya-luotao/dotclaude/compare/d4ac62b...3944815
[0.3.0]: https://github.com/ya-luotao/dotclaude/compare/e16d383...d4ac62b
[0.2.0]: https://github.com/ya-luotao/dotclaude/compare/65a4204...e16d383
[0.1.0]: https://github.com/ya-luotao/dotclaude/commit/65a4204
