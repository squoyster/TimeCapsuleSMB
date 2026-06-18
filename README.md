# TimeCapsuleSMB

Run a modern Samba server on an Apple Time Capsule while keeping the disk auto-mount behavior of Apple’s firmware.

This repo contains host-side scripts for discovery and SSH enablement. Samba deployment and device configuration remain manual.

## What This Does
- Uses mDNS to discover Time Capsules on your network.
- Enables root SSH access using AirPyrt (temporary) to allow configuration.
- Provides a guarded Samba 4.24.3 cross-build workflow for the Time Capsule's NetBSD-derived `evbarm` environment.
- Stages the runtime and configuration under `/Volumes/dk2/.samba` for a manual port-1445 smoke test without changing the existing share layout.

## Status
- mDNS discovery and interactive SSH enable/disable automation are implemented.
- Versioned packaging, minimal installation, startup, and rollback scripts are implemented.
- Cross-build compatibility must still be validated before any PF, boot, or Time Machine integration work.

## Prerequisites
- macOS host (Apple Silicon M1/M2 tested) with Python 3.10+ and `venv`.
- Access to your Time Capsule from the same network.
- The Python 3 AirPyrt port checked out in the sibling directory `../airpyrt-tools`.
- Ability to build/cross-compile for NetBSD `evbarm` (toolchain of your choice).

## Device Notes
- Disk mount path: `/Volumes/dk2/ShareRoot` (where your shared data lives).
- Persistent flash: `/mnt/Flash` (useful for configs and binaries that must survive reboots).
- OpenSSH quirk: legacy DSA host keys require `-oHostKeyAlgorithms=+ssh-dss` when connecting via SSH.

## How It Works (Design)
1. Discover Time Capsules via mDNS; prefer the `.local` hostname over raw IP (e.g., `Basement-AirPort-Time-Capsule.local`).
2. Enable SSH to `root` using AirPyrt so we can provision the box.
3. Copy a validated, versioned Samba build onto the mounted data disk.
4. Keep Apple File Sharing enabled so the disk auto-mounts.
5. Test SMB2/SMB3 directly on port 1445 before considering traffic redirection or persistence.

## Manual Setup (until automated)

1) Discover the Time Capsule
- On macOS, you can enumerate services via `dns-sd` or simply identify the device in AirPort Utility. Prefer the mDNS hostname: `X-AirPort-Time-Capsule.local`.

2) Install the host tools and enable SSH
- Create the project environment and install the sibling Python 3 AirPyrt port:
  ```bash
  make install
  make setup
  ```
- `make setup` discovers devices, prompts for a target and admin password, and
  offers to enable or disable SSH. It can reboot the selected Time Capsule.

3) SSH into the Time Capsule
- Use the legacy host key option if needed:
  ```bash
  ssh -oHostKeyAlgorithms=+ssh-dss root@Basement-AirPort-Time-Capsule.local
  ```

4) Build, stage, test, and persist Samba

Follow [DEPLOYMENT.md](DEPLOYMENT.md). The runbook covers the maintained-release
build gate, capacity calculation, versioned package, read-only preflight,
legacy-SCP transfer, dedicated Time Machine and file shares, PF activation,
multi-Mac testing, persistence, and rollback.

## Security Notes
- AirPyrt's legacy ACP protocol does not provide modern credential protection.
  Use it only on a trusted local network and never for remote administration.
- Be cautious enabling `vfs_fruit` and Time Machine support; follow Samba advisories and keep your build updated.
- Restrict access to trusted subnets/users; avoid exposing SMB to the internet.
- Consider rotating credentials and disabling SSH when not actively administering.

## Troubleshooting
- Disk not mounted: ensure Apple File Sharing remains enabled in AirPort Utility so `/Volumes/dk2/ShareRoot` is present.
- SSH fails with key algo error: add `-oHostKeyAlgorithms=+ssh-dss`.
- No SMB connectivity: verify Samba listens on 1445, then inspect only the dedicated `timecapsule-samba` PF anchor.
- Persistence: verify the firmware-specific boot hook waits for the disk and starts Samba before activating the redirect.

## Roadmap
- Python CLI to:
  - Discover Time Capsules via mDNS and prompt for selection.
  - Continue hardening SSH enable/disable automation around the Python 3 AirPyrt port.
  - Upload Samba artifacts and configs.
  - Configure `pf` redirection and launch services; add boot persistence.

---

This project is unaffiliated with Apple or the Samba team. For educational use only; proceed at your own risk.
