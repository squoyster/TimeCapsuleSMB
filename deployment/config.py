from __future__ import annotations

from dataclasses import dataclass


GIB = 1024**3


def recommended_time_machine_gib(capacity_bytes: int, free_bytes: int) -> int:
    """Reserve 20% of the disk and cap Time Machine at 75% of capacity."""
    if capacity_bytes <= 0 or free_bytes < 0 or free_bytes > capacity_bytes:
        raise ValueError("invalid capacity/free-space values")
    available_after_reserve = free_bytes - int(capacity_bytes * 0.20)
    limit = min(int(capacity_bytes * 0.75), available_after_reserve)
    rounded_gib = (limit // GIB // 10) * 10
    if rounded_gib < 10:
        raise ValueError("less than 10 GiB remains after the required disk reserve")
    return rounded_gib


@dataclass(frozen=True)
class SambaConfig:
    time_machine_max_size: str
    smb_user: str = "tcbackup"
    workgroup: str = "WORKGROUP"

    def render(self) -> str:
        if not self.time_machine_max_size[:-1].isdigit() or self.time_machine_max_size[-1:] not in {
            "G",
            "T",
        }:
            raise ValueError("Time Machine size must look like 500G or 1T")
        if not self.smb_user.replace("_", "").isalnum():
            raise ValueError("SMB user must contain only letters, digits, and underscores")
        return f"""[global]
    server role = standalone server
    workgroup = {self.workgroup}
    security = user
    server min protocol = SMB2_02
    server max protocol = SMB3
    smb ports = 1445
    disable netbios = yes
    load printers = no
    printcap name = /dev/null
    fruit:aapl = yes
    fruit:model = TimeCapsule
    private dir = /Volumes/dk2/.samba/state/private
    state directory = /Volumes/dk2/.samba/state
    cache directory = /Volumes/dk2/.samba/state/cache
    lock directory = /Volumes/dk2/.samba/state/lock
    pid directory = /Volumes/dk2/.samba/state/run
    log file = /Volumes/dk2/.samba/state/log/smbd.%m.log
    max log size = 10240

[TimeMachine]
    path = /Volumes/dk2/ShareRoot/TimeMachine
    valid users = {self.smb_user}
    read only = no
    browseable = yes
    vfs objects = catia fruit streams_xattr
    fruit:time machine = yes
    fruit:time machine max size = {self.time_machine_max_size}
    fruit:metadata = netatalk
    fruit:resource = file

[Files]
    path = /Volumes/dk2/ShareRoot
    valid users = {self.smb_user}
    read only = no
    browseable = yes
    veto files = /TimeMachine/
    delete veto files = no
    vfs objects = catia fruit streams_xattr
    fruit:time machine = no
    fruit:metadata = netatalk
    fruit:resource = file
"""
