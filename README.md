# TimeCapsuleSMB

Run a modern Samba server on an Apple Time Capsule while keeping the disk auto-mount behavior of Apple’s firmware.

This repo contains host-side scripts for discovery and SSH enablement. Samba deployment and device configuration remain manual.

## Relationship to upstream jamesyc/TimeCapsuleSMB

> **Important:** This branch is a **fork of an early snapshot** (commit `582a97c`)
> of [`jamesyc/TimeCapsuleSMB`](https://github.com/jamesyc/TimeCapsuleSMB). The
> upstream project has since evolved into a complete, actively maintained product
> and **independently includes its own Samba 4.24.3 cross-build** that is more
> comprehensive than the one here. **For real-world Time Capsule use, prefer the
> upstream.** This fork's build is retained as a parallel, independent effort.

What upstream did after this snapshot:

- Replaced the old layout (`setup.py`, `discovery/`, `ssh/`, `building/build.sh`)
  with a full `src/timecapsulesmb/` Python package, a `macos/` SwiftUI app,
  prebuilt `bin/` artifacts, and release tags up to **v2.2.7**.
- Ships its own Samba 4.24.3 cross-build in `build/` with a **quilt-style
  28-patch series** (`build/patches/samba4x/`), versus this fork's single
  monolithic `building/samba-4.24.3-hostcc.patch`.
- Targets **three** device lanes (NetBSD 4 BE/LE, NetBSD 7) versus this fork's
  single NetBSD 6 `evbarm` (`arm--netbsdelf`) target.
- Produces a **fully static `smbd`** (runs from a RAM disk with no shared-lib
  dependencies) versus this fork's dynamically-linked nonshared `smbd` (which
  needs `LD_LIBRARY_PATH` on the device).

Upstream carries runtime patches that this fork does **not** — the difference
between "compiles" and "actually serves Time Machine on a Time Capsule":

- **No-pthread appliance runtime** — Time Capsule kernels do not support the
  pthread behavior Samba 4.24 expects; upstream runs `notifyd`/`cleanupd`/
  `scavenger` in the `smbd` parent event loop instead of forking helpers.
- **Time Machine / HFS interop** — durable reconnect across HFS sparsebundle
  allocation-block drift, an `AFP_AfpInfo` `fstatat` NULL-deref crash fix in
  `vfs_fruit`, HFS unknown-owner (`4294967295`) normalization, and resume-key
  IOCTL compound completion.
- **`xattr_tdb` fixes** — missing rows behave like empty xattrs; oversized
  `listxattr` returns `ERANGE` instead of a bogus length.
- **Embedded `srvsvc`** so Finder/`smbclient` share enumeration works without
  external DCE/RPC helpers, plus a NetBSD `getifaddrs()` fallback for kernels
  that hang in the native path.

Both projects independently arrived at the same core Waf fix (derive a fresh
per-target compiler environment for hostcc task generators instead of reusing
the global `bld.env`), which confirms the root cause.

## What This Does
- Uses mDNS to discover Time Capsules on your network.
- Enables root SSH access using AirPyrt (temporary) to allow configuration.
- Provides a guarded Samba 4.24.3 cross-build workflow for the Time Capsule's NetBSD-derived `evbarm` environment.
- Stages the runtime and configuration under `/Volumes/dk2/.samba` for a manual port-1445 smoke test without changing the existing share layout.

## Status
- mDNS discovery and interactive SSH enable/disable automation are implemented.
- Versioned packaging, minimal installation, startup, and rollback scripts are implemented.
- Samba 4.24.3 cross-builds successfully in a NetBSD 10.1 `aarch64` VM for
  the NetBSD 6.0 `evbarm` target. Runtime validation on the Time Capsule is
  still required before any PF, boot, or Time Machine integration work.

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

Licensed under the [GNU GPLv3](LICENSE) or (at your option) any later version, matching upstream `jamesyc/TimeCapsuleSMB` and the Samba project. The Samba source patches under `building/` are GPLv3+ Samba derivatives and inherit that license.

This project is unaffiliated with Apple or the Samba team. For educational use only; proceed at your own risk.
