from __future__ import annotations

import shlex
from typing import Any, Iterable, List, Optional, Tuple, Type


def _load_airpyrt() -> tuple[Type[Any], Type[Any]]:
    try:
        from acp.client import ACPClient
        from acp.property import ACPProperty
    except ImportError as exc:
        raise RuntimeError(
            "Python 3 AirPyrt is not installed. Run 'make install' from the project root."
        ) from exc
    return ACPClient, ACPProperty


def _set_airpyrt_property(host: str, password: str, name: str, value: int) -> None:
    client_type, property_type = _load_airpyrt()
    client = client_type(host, password)
    try:
        client.connect()
        client.set_properties({name: property_type(name, value)})
    finally:
        client.close()


def set_dbug(
    host: str,
    password: str,
    value_hex: str,
    *,
    python_candidates: Optional[Iterable[str]] = None,
    verbose: bool = True,
) -> None:
    """Set the AirPyrt debug property without exposing the password in argv."""
    del python_candidates  # Retained for compatibility with existing callers.
    if verbose:
        print(f"Setting AirPyrt dbug={value_hex} on {host}")
    try:
        value = int(value_hex, 0)
        _set_airpyrt_property(host, password, "dbug", value)
    except Exception as exc:
        raise RuntimeError(f"Failed to set dbug={value_hex} via AirPyrt") from exc


def reboot(
    host: str,
    password: str,
    *,
    python_candidates: Optional[Iterable[str]] = None,
    verbose: bool = True,
) -> None:
    """Reboot via the acRB property in the Python 3 AirPyrt API."""
    del python_candidates  # Retained for compatibility with existing callers.
    if verbose:
        print(f"Rebooting device via AirPyrt: {host}")
    try:
        _set_airpyrt_property(host, password, "acRB", 0)
    except Exception as exc:
        raise RuntimeError("Reboot command failed") from exc


# --- SSH helper (run commands on the device) ---

def ssh_run_command(
    host: str,
    password: str,
    command: str,
    *,
    timeout: int = 30,
    verbose: bool = True,
) -> Tuple[int, str]:
    """Run a shell command on the device via system ssh using pexpect.

    Uses password auth for user 'root', allows legacy DSA host keys, and disables
    strict host key checking. Returns (exit_code, combined_output).
    """
    try:
        import pexpect
    except Exception:
        raise RuntimeError("pexpect not available. Run 'make install' to install requirements.")

    ssh_cmd = [
        "ssh",
        "-o", "HostKeyAlgorithms=+ssh-dss",
        "-o", "PubkeyAuthentication=no",
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null",
        f"root@{host}",
        command,
    ]
    if verbose:
        print("SSH exec:", " ".join(shlex.quote(x) for x in ssh_cmd))

    import pexpect
    child = pexpect.spawn(ssh_cmd[0], ssh_cmd[1:], encoding="utf-8", timeout=timeout)
    out_chunks: List[str] = []
    try:
        i = child.expect(["[Pp]assword:", pexpect.EOF, pexpect.TIMEOUT], timeout=timeout)
        if i == 0:
            child.sendline(password)
            child.expect(pexpect.EOF, timeout=timeout)
        out_chunks.append(child.before or "")
    finally:
        try:
            child.close()
        except Exception:
            pass
    rc = child.exitstatus if child.exitstatus is not None else (child.signalstatus or 1)
    return rc, "".join(out_chunks)
