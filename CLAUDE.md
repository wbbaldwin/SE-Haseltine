# CLAUDE.md

## Project Overview

**SE-Haseltine** is a personal collection of Lua automation scripts for the
[Praetor](https://github.com/cyber-godzilla/praetor) game client for *The
Eternal City* (TEC). It follows the same script format and conventions as the
community [praetor-scripts](https://github.com/cyber-godzilla/praetor-scripts)
repo and is meant to be loaded alongside it (see README.md), reusing its
shared libraries rather than duplicating them.

Praetor loads any `.lua` file that returns a table with `reactions` and/or
`on_start` as a **mode**, runnable via `/mode <name>`. Any other `.lua` file
is a **library**, loaded via `require()`.

## Script Structure

```lua
local M = {}

M.usage = '<item> [count]'   -- args only, no mode name; omit when the mode takes none
M.desc = 'One line, sentence case, no trailing period'
M.chains = true              -- only when after: is genuinely honored (see Mode Chaining)
M.hidden = false             -- true keeps it out of the command hint; it still runs

function M.on_start(args)
    -- Called when mode is activated via /mode <name> [args]
end

function M.on_stop()
    -- Optional. Called when mode is deactivated. Pending queued commands from
    -- the outgoing mode are dropped before this runs, so send() here (sheathe,
    -- stand, etc.) still reaches the server.
end

M.reactions = {
    {
        match = 'pattern',           -- string or table; * = any chars, ? = single char
        action = function(text) end, -- called when pattern matches game text
        condition = function() end,  -- optional: only fire if returns true
        delay = 500,                 -- optional: ms delay before action
    },
}

return M
```

Matching is case-sensitive substring/wildcard matching. The first reaction
whose pattern matches wins — order reactions from most to least specific.

## Lua API (provided by Praetor)

```lua
send(command [, delay_ms])            -- queue a command
set_mode(name [, {args}])             -- switch mode
notify(title, message)                -- desktop notification
log(message)
random_item(table)
time.now() / time.since(ms)
state.get(key) / state.set(key, val)  -- per-mode state, cleared on mode switch
state.persist(key)                    -- survive mode switches and app restarts
state.display(key, label)             -- show in sidebar, enables /toggle and /set
state.mode                            -- read-only: current mode name
status.health / status.fatigue / status.encumbrance / status.satiation
metrics.track(key, label) / metrics.inc(key) / metrics.dec(key)
metrics.set(key, value) / metrics.get(key)
set_timeout(fn, ms) / set_interval(fn, ms) / clear_timer(id)
```

Full reference: `docs/lua-api.md` in the Praetor repo.

## Reusing praetor-scripts

Don't reimplement what already exists upstream — `require()` it:

- **`lib_strings`** — shared pattern tables (`unbusy`, `success`, `must_stand`, ...)
- **`lib_combat`** — attack rotation, `[Success:]` dispatch (`handle_success`),
  kill/KO handling, approach, watchdog stall recovery
- **`lib_after`** — mode chaining (`after.parse(args)` / `after.finish()`)
- **`lib_locksmithing`** — customer arrival/greeting patterns

A new weapon macro should be a thin `lib_combat` consumer (own attack-string
list, own approach/kill macro names) rather than a rewritten copy of
`macro.lua`/`falx_macro.lua`. A new non-combat bot should follow the shape of
`locksmith.lua` (explicit state machine over `state.get/set`, one reaction per
server confirmation string) unless the skill genuinely needs something
different.

## Macro Mode Architecture (combat)

Every weapon macro in this repo should follow the pattern established by
`praetor-scripts`' combat modes:

- One `[Success:]` reaction dispatches through `combat.handle_success(text,
  attack_fn)` — it identifies kills, KOs, and rotates the attack list only on
  genuine player attack rolls (not stun/drag/eviscerate/etc).
- Anti-idle: if 5+ seconds pass with no command sent, the next `[Success:]`
  (or the watchdog timer) forces an attack instead of stalling.
- Combat macros run indefinitely — no completion point, so `M.chains` stays
  unset unless the mode has a genuine end condition (e.g. fatigue-driven,
  like `lizard_macro`).
- Required in-game macros (attack rotation slots, approach, advance, kill,
  rewield, stance) are documented in each mode's header comment, matching the
  README convention in `praetor-scripts`.

## Mode Metadata (`usage` / `desc` / `chains` / `hidden`)

Declare these directly after `local M = {}`, in that order, on every mode:

| Field | Meaning |
|---|---|
| `usage` | Arguments only, no mode name. `<required>`, `[optional]`, `[flagword]`, `a\|b\|c`, `key:<value>`, `[repeatable...]`. Omit if the mode takes none. |
| `desc` | One line, sentence case, no trailing period. What it does, not how. |
| `chains` | `true` only when `on_start` calls `after.parse(args)` *and* a completion point calls `after.finish()`. |
| `hidden` | `true` keeps it out of the `/mode` hint and `/list`. The mode still loads and still runs. |

Nothing validates arguments against `usage` — keep it accurate anyway, and
update it in the same change that alters a mode's arguments.

## Mode Chaining (`after:`)

Any mode with a real completion point should support `after:<mode>` via
`lib_after`: call `after.parse(args)` at the top of `on_start`, and replace
terminal `set_mode('disable')` calls with `after.finish()` (or
`after.finish('fallback')`). Keep bare `set_mode('disable')` on
argument-validation aborts so a failed run doesn't chain forward.

## File Naming

- Mode files are named after their mode: `pilum.lua` → `/mode pilum`
- Library files use the `lib_` prefix: `lib_healing.lua`
- Flat directory — no subfolders, matching `praetor-scripts`
- `private/` is gitignored, for character-specific or secret-adjacent local
  modes that shouldn't be committed

## Planned Skillsets

Tracked here until each has a script; update as work lands.

**Combat** (weapon macros, one mode per skillset — see README for which
weapons `praetor-scripts` already covers before duplicating):
- [ ] _(none started — needs weapon choice + in-game attack/approach/kill
  strings before a mode can be written)_

**Non-combat**:
- [ ] Healing — not covered upstream; needs the skill's command set and
  server response strings
- [ ] Locksmithing — `praetor-scripts` already has `board` / `lock_job` /
  `wire_to_picks` / `locksmith`; only add something here if it's a genuine
  gap or a character-specific variant

## Testing

Praetor has no script test harness — validate by running the mode in-game
against real server output and watching `state.display()`'d values / the log.
When in doubt about a pattern, prefer matching on the game's exact
confirmation text (as captured from a real session) over a guessed string.
