# AGENTS.md — building/

## Purpose

Samba cross-compile tooling that produces modern SMB2/SMB3 + `vfs_fruit` (Time Machine) binaries for the Apple Time Capsule's NetBSD-derived `evbarm` firmware (32-bit ARM, NetBSD 6.0). Not part of the runtime CLI.

## Ownership

- `build.sh` — historical commented narrative of one Samba 4.8.12 build (read-only reference).
- `build-prereqs.sh` — executable: stages GMP → nettle → GnuTLS into `$PREFIX`.
- `build-samba.sh` — executable: patches, configures, builds, and installs Samba 4.24.3.
- `samba-4.24.3-hostcc.patch` — the cross-build compatibility patch (see Local Contracts).
- `netbsd-arm-4.24.3.txt` — waf cross-answers for the target.

## Local Contracts

- **Build host**: NetBSD 10.1 `aarch64` VM (UTM). **Cross-target**: NetBSD 6 / `evbarm` = the Time Capsule (TRIPLE `arm--netbsdelf`, not `-eabi`). Toolchain in `TOOLDIR`, sysroot in `DESTDIR` (built once via NetBSD 6 `build.sh tools` + `distribution`); do not rebuild it.
- **Env vars** drive the scripts: `SAMBA_SOURCE`, `TOOLDIR`, `SYSROOT`, `TRIPLE`, `PREFIX`, `CROSS_ANSWERS`, `JOBS`.
- The hostcc patch fixes real 4.24.3 cross issues: per-target compiler env isolation (`bld.env.derive()` so flags don't accumulate across targets — the root cause of the old `samba_builtin_subsystem`/`ndr is missing` failure), `Task.py` byte-size `ARG_MAX` check (NetBSD `ARG_MAX`=262144, not arg-count 200000), Heimdal duplicate-typedef guards, popt glob `!__NetBSD__` guard, `ENOTRECOVERABLE`→`EIO`, `_INCOMPLETE_XOPEN_C063` for `fstatat`/`AT_SYMLINK_NOFOLLOW`, `SAMBA_BINARY` disables non-installed/non-hostcc/non-selftest targets, `--disable-symbol-versions`.
- `build-samba.sh` guards the patch with a checksum stamp (`.timecapsule-samba-4.24.3.patch-id`): it refuses to build a tree that is patched without a matching stamp, preventing silent partial patching. It also refuses if `$PREFIX/samba-min` already exists.
- Configure is file-server-only: `--cross-compile --cross-answers=netbsd-arm-4.24.3.txt --hostcc=/usr/bin/cc --disable-python --without-{ad-dc,ads,ldap,winbind,cups,pam,systemd,libunwind,json,quotas,acl-support} --with-static-modules=catia,fruit,streams_xattr --with-shared-modules='!DEFAULT' --nonshared-binary=smbd/smbd`.
- `vfs_fruit`/`streams_xattr`/`catia` are compiled **static** into `smbd`. Output staged to `$PREFIX/samba-min` (`sbin/smbd`, `bin/smbpasswd`, `bin/testparm`, …). `smbd` depends on staged `-lgnutls` plus NetBSD 6 system libs (`-lz -lutil -lintl -lresolv -lcrypt -lpthread -lc`).
- On-device run: `export LD_LIBRARY_PATH=/Volumes/dk2/lib`; bind to high port `1445` and redirect `445` via `pf` only under explicit device config (keep AFP on so the disk auto-mounts).
- `build.sh` is the legacy 4.8.12 record; prefer `build-samba.sh` for new builds.

## Work Guidance

Cross-compile happens off-host in the NetBSD VM, not in this checkout. Do not commit downloaded source trees, the cross-toolchain, staged binaries, or build output.

## Verification

No host-side check proves the binaries run on the device. Confirm staged artifacts are `ELF 32-bit LSB executable, ARM, version 1 (ARM), dynamically linked, interpreter /usr/libexec/ld.elf_so, for NetBSD 6.0`. Real verification is on-device (`smbd -i -s smb.conf`, SMB2/3 + Time Machine). Record exact NetBSD/Samba versions, configure flags, and target-device results when changing this procedure.

## Child DOX Index

(none)
