from __future__ import annotations

import io
import tarfile
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import deploy
from deployment.config import GIB, SambaConfig, recommended_time_machine_gib
from deployment.package import CONTROL_FILES, create_bundle, validate_stage


class QuotaTests(unittest.TestCase):
    def test_uses_75_percent_capacity_when_disk_is_empty(self) -> None:
        self.assertEqual(recommended_time_machine_gib(2000 * GIB, 2000 * GIB), 1500)

    def test_preserves_20_percent_capacity_from_current_free_space(self) -> None:
        self.assertEqual(recommended_time_machine_gib(2000 * GIB, 1000 * GIB), 600)

    def test_rejects_insufficient_remaining_space(self) -> None:
        with self.assertRaisesRegex(ValueError, "less than 10 GiB"):
            recommended_time_machine_gib(2000 * GIB, 400 * GIB)


class ConfigTests(unittest.TestCase):
    def test_time_machine_and_files_are_separate(self) -> None:
        rendered = SambaConfig("1500G").render()

        self.assertIn("server min protocol = SMB2_02", rendered)
        self.assertIn("smb ports = 1445", rendered)
        self.assertIn("path = /Volumes/dk2/ShareRoot/TimeMachine", rendered)
        self.assertIn("fruit:time machine max size = 1500G", rendered)
        self.assertIn("veto files = /TimeMachine/", rendered)
        self.assertNotIn("guest ok = yes", rendered)

    def test_rejects_unsafe_user_name(self) -> None:
        with self.assertRaisesRegex(ValueError, "SMB user"):
            SambaConfig("1500G", "bad user").render()


class BundleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.stage = self.root / "stage"
        for relative in (
            "samba-min/sbin/smbd",
            "samba-min/bin/smbpasswd",
            "samba-min/bin/testparm",
        ):
            binary = self.stage / relative
            binary.parent.mkdir(parents=True, exist_ok=True)
            binary.write_text("fake executable", encoding="ascii")
            binary.chmod(0o755)
        (self.stage / "BUILD-METADATA").write_text(
            "samba_version=4.24.3\n"
            "target=arm--netbsdelf-eabi\n"
            "configure_flags=file-server-only,static-catia-fruit-streams_xattr\n",
            encoding="ascii",
        )
        self.templates = self.root / "templates"
        self.templates.mkdir()
        for name in CONTROL_FILES:
            path = self.templates / name
            path.write_text("#!/bin/sh\n", encoding="ascii")
            path.chmod(0o755)

    def test_rejects_wrong_version(self) -> None:
        (self.stage / "BUILD-METADATA").write_text(
            "samba_version=4.8.12\n"
            "target=arm--netbsdelf-eabi\n"
            "configure_flags=file-server-only,static-catia-fruit-streams_xattr\n",
            encoding="ascii",
        )
        with self.assertRaisesRegex(ValueError, "not Samba 4.24.3"):
            validate_stage(self.stage)

    def test_bundle_contains_runtime_control_and_checksum(self) -> None:
        output = self.root / "bundle.tar.gz"
        real_templates = Path(deploy.__file__).resolve().parent / "deployment" / "templates"
        bundle, checksum = create_bundle(
            self.stage, output, SambaConfig("1500G"), real_templates
        )

        self.assertTrue(bundle.is_file())
        self.assertTrue(checksum.is_file())
        with tarfile.open(bundle) as archive:
            names = archive.getnames()
        prefix = "timecapsule-samba-4.24.3"
        self.assertIn(f"{prefix}/runtime/samba-min/sbin/smbd", names)
        self.assertIn(f"{prefix}/control/smb.conf", names)
        self.assertIn(f"{prefix}/MANIFEST.json", names)
        self.assertIn(f"{prefix}/control/rollback-samba.sh", names)


class CliTests(unittest.TestCase):
    def test_quota_command(self) -> None:
        output = io.StringIO()
        with redirect_stdout(output):
            result = deploy.main(["quota", "--capacity-gib", "2000", "--free-gib", "2000"])
        self.assertEqual(result, 0)
        self.assertEqual(output.getvalue(), "1500G\n")


if __name__ == "__main__":
    unittest.main()
