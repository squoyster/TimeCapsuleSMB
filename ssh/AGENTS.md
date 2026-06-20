# AGENTS.md — ssh/

## Purpose

Enable/disable SSH on Apple AirPort/Time Capsule devices via the Python 3 AirPyrt (`acp`) API, and run shell commands on a device over SSH.

## Ownership

- Package `ssh/`: `common.py` (AirPyrt + SSH helpers), `enable_ssh.py`, `disable_ssh.py`.
- Depends on the Python 3 AirPyrt port (imported in-process) and `pexpect`.

## Local Contracts

- **In-process AirPyrt** (`common.py:_load_airpyrt`): imports `ACPClient` from `acp.client` and `ACPProperty` from `acp.property`. If the import fails it raises `RuntimeError("Python 3 AirPyrt is not installed. Run 'make install'.")`. Do not restore Python 2 interpreter discovery or shell out to the `acp` CLI.
- **Property writes** (`common.py:_set_airpyrt_property`): `ACPClient(host, password)` → `connect()` → `set_properties({name: ACPProperty(name, value)})`, `close()` in a `finally`. The password stays in-process; it is never placed in argv.
- **Enable SSH** = set `dbug` to `0x3000` (`set_dbug`) then `reboot` (sets `acRB=0`). **Disable SSH** = SSH in and remove `dbug` on-device (setting `dbug=0x0000` does not persist on some firmware; the property must be removed), then reboot.
- `set_dbug` and `reboot` keep a `python_candidates` kwarg only for backward compatibility with older callers; it is ignored (`del`). Do not reintroduce CLI-interpreter selection through it.
- **SSH exec** (`common.py:ssh_run_command`): system `ssh` over `pexpect`, `root@host`, always with `-o HostKeyAlgorithms=+ssh-dss` (legacy DSA), plus `PubkeyAuthentication=no`, `StrictHostKeyChecking=no`, `UserKnownHostsFile=/dev/null`. Returns `(exit_code, combined_output)`. Apply the same `-oHostKeyAlgorithms=+ssh-dss` to any manual `ssh`/`scp` to a Time Capsule; do not weaken global SSH config.
- The AirPort **admin** password is the SSH `root` password (not the Wi-Fi password).

## Work Guidance

(empty)

## Verification

Smoke-test imports against the project venv:

```bash
.venv/bin/python -c "from ssh.common import set_dbug, reboot, ssh_run_command"
```

Unit tests mock `pexpect` and the `acp` import; they must not connect to or reboot a real device. See `tests/test_ssh_common.py`.

## Child DOX Index

(none)
