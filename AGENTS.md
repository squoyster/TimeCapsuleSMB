# AGENTS.md

## Project purpose

TimeCapsuleSMB is experimental tooling and documentation for running a modern
Samba server on an Apple Time Capsule. The host-side tools discover devices over
mDNS and use AirPyrt to enable or disable root SSH. The target is the Time
Capsule's NetBSD-derived `evbarm` firmware, not macOS.

Licensed under GPLv3+ (see `LICENSE`), matching upstream `jamesyc/TimeCapsuleSMB`
and the Samba project. The Samba source patches under `building/` are GPLv3+
Samba derivatives and must not be relicensed permissively.

## Repository map

- `setup.py`: interactive discovery and SSH enable/disable coordinator.
- `discovery/`: Python 3 mDNS/Bonjour discovery using `zeroconf`.
- `ssh/`: AirPyrt, reboot, and legacy-SSH helpers.
- `deploy.py` and `deployment/`: offline configuration/bundle generation and
  conservative device-side install, activation, and rollback scripts.
- `building/`: Samba cross-compile for the Time Capsule's NetBSD 6 `evbarm`
  target. `build.sh` is a commented narrative of one historical build (read it,
  do not run it as-is). `build-prereqs.sh` and `build-samba.sh` are the
  executable recipes (Samba 4.24.3) driven by `samba-4.24.3-hostcc.patch` and
  `netbsd-arm-4.24.3.txt`. See `building/AGENTS.md`.
- `README.md`: supported workflow, device layout, and security background.
- `todo.md`: historical design notes; prefer the implementation and README when
  they disagree with it.

## Development environment

- The host environment is macOS with Python 3.10 or newer.
- Install host dependencies with `make install`; this creates `.venv` and may
  access package indexes.
- Run discovery with `make discover` or
  `.venv/bin/python discovery/discover_timecapsules.py`.
- Run the interactive coordinator with `make setup` only when live-device work
  is explicitly intended.
- Use the Python 3.10+ AirPyrt port from the sibling `../airpyrt-tools`
  checkout. `make install` installs it in editable mode into this project's
  `.venv`; override `AIRPYRT_DIR` when the checkout is elsewhere.
- Import `ACPClient` and `ACPProperty` in process. Do not restore Python 2
  interpreter discovery or invoke the `acp` CLI with a password in argv.
- Do not commit `.venv/`, `.deps/`, downloaded source trees,
  cross-toolchains, staged binaries, or generated build output.

## Coding conventions

- Keep host automation compatible with Python 3.10+ and preserve the existing
  package boundaries between discovery, SSH operations, and orchestration.
- Use type hints and `from __future__ import annotations` consistently with the
  existing modules. Prefer `pathlib`, `subprocess` argument lists, and standard
  library structured APIs over shell-string construction.
- Keep CLI entry points thin. Put behavior in importable functions that can be
  tested without network access or physical hardware.
- Discovery is best-effort and concurrent: do not let callback failures crash
  the process, and protect shared collector state.
- Prefer an mDNS hostname for user-facing SSH connections. AirPyrt operations
  should prefer a routable IPv4 address and avoid link-local IPv4 when possible.
- Preserve actionable CLI errors and nonzero exit statuses. Do not silently
  ignore failures in authentication, reboot, SSH state changes, or persistence
  checks.
- Update `README.md` when commands, prerequisites, device paths, or the workflow
  change. Keep target-specific build findings in `building/build.sh` clearly
  separated from executable commands.

## Device and credential safety

- Device operations are destructive or disruptive. Do not run `make setup`,
  AirPyrt/acp commands, SSH enable/disable helpers, reboot commands, remote shell
  commands, `pfctl`, uploads, or Samba installation against a real device unless
  the user explicitly requests it and the target host/IP is unambiguous.
- Never use an inferred or discovered device as an implicit mutation target.
  Discovery-only commands are acceptable, but report that they access the local
  network.
- Never hard-code, persist, print, log, or include an admin password in an error
  message. Avoid placing secrets in command-line arguments where a safer input
  channel is available. Redact commands before verbose logging.
- Retain the legacy SSH host-key option only for Time Capsule connections:
  `-oHostKeyAlgorithms=+ssh-dss`. Do not weaken global SSH configuration.
- Keep Apple File Sharing enabled because it triggers disk auto-mounting. The
  shared disk is `/Volumes/dk2/ShareRoot`; persistent flash is `/mnt/Flash`.
  Do not change, erase, format, or assume either location exists without an
  explicit check.
- Bind replacement Samba to high port `1445` and redirect port `445` only as
  part of an explicitly approved device configuration. Modern
  SMB2/SMB3 clients do not need NetBIOS port `139`.
  Never expose SMB or root SSH to the public internet.

## Validation

The unit tests use the standard library's `unittest` framework and must remain
hardware-independent. Run:

```sh
python3 -m compileall -q setup.py deploy.py deployment discovery ssh
PYTHONPATH=../airpyrt-tools python3 -m unittest discover -s tests -v
```

When `.venv` is installed, `make test` runs the same tests with the editable
AirPyrt dependency. Add focused unit tests for new logic, especially address selection, discovery
filtering, command construction, and state polling. Mock `zeroconf`, sockets,
`subprocess`, `pexpect`, time, and user input; tests must not discover, connect
to, authenticate to, or reboot a real device. If dependencies are already
installed, also exercise non-mutating CLI parsing or JSON output as relevant.

Do not claim that cross-compiled Samba works from host-side checks alone. Record
the exact NetBSD/Samba versions, configure flags, and target-device verification
when changing the cross-build procedure.

## Child DOX Index

- `ssh/` — AirPyrt reboot and legacy-SSH helpers; owns the protocol gotchas. See `ssh/AGENTS.md`.
- `building/` — Samba cross-compile recipe plus executable `build-prereqs.sh` / `build-samba.sh` for the NetBSD 6 `evbarm` target. See `building/AGENTS.md`.
- `deployment/` — offline configuration/bundle generation and conservative device-side install, activation, and rollback scripts. Covered by this parent (no separate doc).
- `discovery/` — single mDNS/Bonjour discovery module. Covered by this parent.
- `tests/` — hardware-independent unittest suite. Covered by this parent.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **TimeCapsuleSMB**. Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({query: "concept"})` to find execution flows instead of grepping.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/TimeCapsuleSMB/context` | Codebase overview, check index freshness |
| `gitnexus://repo/TimeCapsuleSMB/clusters` | All functional areas |
| `gitnexus://repo/TimeCapsuleSMB/processes` | All execution flows |
| `gitnexus://repo/TimeCapsuleSMB/process/{name}` | Step-by-step execution trace |

<!-- gitnexus:end -->
