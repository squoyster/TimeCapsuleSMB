from __future__ import annotations

import hashlib
import json
import shutil
import tarfile
import tempfile
from pathlib import Path

from . import SAMBA_VERSION
from .config import SambaConfig


CONTROL_FILES = (
    "activate-samba.sh",
    "install-release.sh",
    "preflight.sh",
    "provision-smb-user.sh",
    "rollback-samba.sh",
    "start-samba.sh",
)


def validate_stage(stage: Path, version: str = SAMBA_VERSION) -> None:
    required_binaries = (
        stage / "samba-min" / "sbin" / "smbd",
        stage / "samba-min" / "bin" / "smbpasswd",
        stage / "samba-min" / "bin" / "testparm",
    )
    metadata = stage / "BUILD-METADATA"
    for binary in required_binaries:
        if not binary.is_file() or not binary.stat().st_mode & 0o111:
            raise ValueError(f"missing executable from stage: {binary}")
    if not metadata.is_file():
        raise ValueError(f"missing build metadata: {metadata}")
    values = dict(
        line.split("=", 1)
        for line in metadata.read_text(encoding="utf-8").splitlines()
        if "=" in line
    )
    if values.get("samba_version") != version:
        raise ValueError(f"stage is not Samba {version}")
    if "evbarm" not in values.get("target", "") and "arm" not in values.get("target", ""):
        raise ValueError("stage metadata does not identify an ARM target")
    if values.get("configure_flags") != "file-server-only,static-catia-fruit-streams_xattr":
        raise ValueError("stage metadata does not confirm the required static VFS modules")


def _file_checksums(root: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    for path in sorted(root.rglob("*")):
        if path.is_file() and not path.is_symlink():
            checksums[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return checksums


def create_bundle(
    stage: Path,
    output: Path,
    config: SambaConfig,
    templates: Path,
    version: str = SAMBA_VERSION,
) -> tuple[Path, Path]:
    validate_stage(stage, version)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="timecapsule-samba-") as temp:
        root = Path(temp) / f"timecapsule-samba-{version}"
        runtime = root / "runtime"
        control = root / "control"
        shutil.copytree(stage, runtime, symlinks=True)
        control.mkdir(parents=True)
        for name in CONTROL_FILES:
            shutil.copy2(templates / name, control / name)
        (control / "smb.conf").write_text(config.render(), encoding="utf-8")
        manifest = {
            "samba_version": version,
            "target": "NetBSD 6 evbarm",
            "runtime_root": "/Volumes/dk2/.samba",
            "smb_port": 1445,
            "sha256": _file_checksums(root),
        }
        (root / "MANIFEST.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        with tarfile.open(output, "w:gz", dereference=False) as archive:
            archive.add(root, arcname=root.name)

    checksum = hashlib.sha256(output.read_bytes()).hexdigest()
    checksum_path = output.with_suffix(output.suffix + ".sha256")
    checksum_path.write_text(f"{checksum}  {output.name}\n", encoding="ascii")
    return output, checksum_path
