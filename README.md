# SE-Haseltine

Personal [Praetor](https://github.com/cyber-godzilla/praetor) Lua automation
scripts for playing *The Eternal City* (TEC). This repo is a companion to the
community [praetor-scripts](https://github.com/cyber-godzilla/praetor-scripts)
collection: it holds character-specific combat rotations (one mode per weapon
skillset) and non-combat automation (healing, locksmithing, and other trade
skills) built on top of Praetor's Lua scripting engine.

## Goal

Complete, hands-off automation of routine gameplay:

- **Combat** — a macro mode per weapon skillset, each driving an attack
  rotation, approach/advance handling, and kill detection off the game's
  `[Success:]` and unbusy lines.
- **Non-combat** — bots for skill trades (healing, locksmithing, etc.) that
  queue the right command for whatever state the character/room is in and
  react to the server's confirmation text.

## Setup

Praetor loads scripts from any number of configured directories, so this repo
runs alongside `praetor-scripts` rather than replacing it:

```bash
git clone https://github.com/wbbaldwin/SE-Haseltine.git ~/se-haseltine-scripts
git clone https://github.com/cyber-godzilla/praetor-scripts.git ~/praetor-scripts
```

Add both to `~/.config/praetor/config.yaml`:

```yaml
scripts:
  - ~/praetor-scripts
  - ~/se-haseltine-scripts
```

Then **Esc → Reload Scripts** in Praetor. Modes in this repo `require()`
shared libraries from `praetor-scripts` (`lib_strings`, `lib_combat`,
`lib_after`, ...) instead of duplicating them, so both directories need to be
loaded for these scripts to work.

## Layout

Flat directory, same convention as `praetor-scripts`:

- `<mode>.lua` — a mode file, run via `/mode <mode>`
- `lib_<name>.lua` — a library loaded via `require('lib_<name>')`, never a
  mode itself
- `private/` — gitignored; character-specific secrets or one-off local modes

See [CLAUDE.md](CLAUDE.md) for the full scripting conventions and the current
build status of each skillset.

## Status

Nothing is implemented yet — this repo is scaffolding for the automation
project described above. See CLAUDE.md for what's planned per skillset.

## Reference

- [Praetor Lua API reference](https://github.com/cyber-godzilla/praetor/blob/main/docs/lua-api.md)
- [praetor-scripts conventions](https://github.com/cyber-godzilla/praetor-scripts/blob/main/CLAUDE.md)

## License

GPL v3, matching Praetor itself.
