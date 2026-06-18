from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from ssh.common import reboot, set_dbug


class AirPyrtPropertyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = MagicMock()
        self.client_type = MagicMock(return_value=self.client)
        self.property_type = MagicMock(side_effect=lambda name, value: (name, value))
        self.loader = patch(
            "ssh.common._load_airpyrt",
            return_value=(self.client_type, self.property_type),
        )
        self.loader.start()
        self.addCleanup(self.loader.stop)

    def test_set_dbug_uses_integer_property_value(self) -> None:
        set_dbug("192.0.2.1", "secret", "0x3000", verbose=False)

        self.client_type.assert_called_once_with("192.0.2.1", "secret")
        self.property_type.assert_called_once_with("dbug", 0x3000)
        self.client.set_properties.assert_called_once_with({"dbug": ("dbug", 0x3000)})
        self.client.close.assert_called_once_with()

    def test_reboot_sets_acrb_and_closes_client(self) -> None:
        reboot("time-capsule.local", "secret", verbose=False)

        self.property_type.assert_called_once_with("acRB", 0)
        self.client.set_properties.assert_called_once_with({"acRB": ("acRB", 0)})
        self.client.close.assert_called_once_with()

    def test_client_closes_when_setting_property_fails(self) -> None:
        self.client.set_properties.side_effect = OSError("network failure")

        with self.assertRaisesRegex(RuntimeError, "Failed to set dbug"):
            set_dbug("192.0.2.1", "secret", "0x3000", verbose=False)

        self.client.close.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
