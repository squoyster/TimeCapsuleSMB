# Samba Deployment Runbook

This runbook stages Samba 4.24.3 without disabling Apple File Sharing. It does
not contact a device unless you run the commands in the device sections.

## Safety gates

- Do not fall back to Samba 4.8.12. The package command rejects other versions.
- Keep Apple File Sharing enabled so `/Volumes/dk2/ShareRoot` mounts.
- Do not put the runtime or logs on `/mnt/Flash`; it is small and write-limited.
- Do not activate a port redirect until Samba is listening on port 1445.
- Do not install a startup hook until its persistence is verified on the actual
  firmware. The repository intentionally does not guess a boot-hook path.
- Keep a second administrator session open while testing PF changes.

Set the target once for the examples:

```sh
export TC_HOST=Basement-AirPort-Time-Capsule.local
export TC_SSH='ssh -oHostKeyAlgorithms=+ssh-dss root@'"$TC_HOST"
```

## 1. Read-only device preflight

Enable SSH with `make setup`, then run the inspection script over standard
input. This makes no device changes:

```sh
$TC_SSH 'sh -s' < deployment/templates/preflight.sh | tee preflight.txt
```

Stop unless the output confirms all of the following:

- NetBSD `evbarm`, `/Volumes/dk2/ShareRoot`, and `/mnt/Flash` are present.
- The data disk has enough free space for existing files plus backups.
- `tar`, `gzip`, `pfctl`, `ifconfig`, `netstat`, `id`, and `readlink` exist.
- The LAN interface and existing PF/startup configuration are identified.
- A persistent, non-root Unix account can be created for `tcbackup`, or an
  existing suitable account can be selected and passed as `--smb-user` when
  packaging.

Calculate the shared Time Machine cap from the disk capacity and free space in
GiB. The result preserves 20% of total capacity and never assigns more than 75%
to Time Machine:

```sh
python3 deploy.py quota --capacity-gib 2000 --free-gib 2000
# 1500G
```

## 2. Build in the NetBSD cross-build VM

Download Samba 4.24.3 and its detached signature from the official Samba
stable directory. Verify the signature using Samba's published signing key
before extracting it. Do not build an unsigned source archive.

Prepare the NetBSD 6 `evbarm` cross-toolchain, reviewed Waf cross-answers, and
all target dependencies. Then use an empty staging directory:

```sh
export SAMBA_SOURCE=/root/tc-build/samba-4.24.3
export TOOLDIR=/root/netbsd6/usr/src/obj/tooldir.NetBSD-*/
export SYSROOT=/root/netbsd6/usr/src/obj/destdir.evbarm
export TRIPLE=arm--netbsdelf-eabi
export CROSS_ANSWERS=/root/tc-build/netbsd-arm-4.24.3.txt
export PREFIX=/root/tc-stage-4.24.3
export JOBS=2

/path/to/TimeCapsuleSMB/building/build-samba.sh
```

The build is successful only if `$PREFIX/samba-min/sbin/smbd` and
`$PREFIX/BUILD-METADATA` exist. Configure or compile failures are a deployment
stop, not permission to use the historical 4.8.12 build.

## 3. Package on the Mac

Copy the complete stage directory from the VM to the Mac. Do not copy only
`smbd`; shared libraries and modules are part of the runtime.

```sh
python3 deploy.py package \
  --stage /path/to/tc-stage-4.24.3 \
  --time-machine-max-size 1500G \
  --smb-user tcbackup

shasum -a 256 -c dist/timecapsule-samba-4.24.3.tar.gz.sha256
```

The archive contains the staged runtime, rendered `smb.conf`, build metadata,
and device control scripts. The configuration provides:

- SMB2/SMB3 on port 1445; NetBIOS/port 139 is disabled.
- A dedicated `TimeMachine` share at `ShareRoot/TimeMachine`.
- A `Files` share at `ShareRoot` that hides `TimeMachine`.
- `catia`, `fruit`, and `streams_xattr` with AppleDouble metadata/resource
  forks and a shared Time Machine capacity limit.

## 4. Transfer and stage the release

Modern `scp` defaults to SFTP, which this firmware does not provide. Force the
legacy SCP protocol with `-O`:

```sh
$TC_SSH 'mkdir -p /Volumes/dk2/.samba/incoming'
scp -O -oHostKeyAlgorithms=+ssh-dss \
  dist/timecapsule-samba-4.24.3.tar.gz \
  root@"$TC_HOST":/Volumes/dk2/.samba/incoming/

$TC_SSH 'cd /Volumes/dk2/.samba/incoming && \
  tar xzf timecapsule-samba-4.24.3.tar.gz && \
  sh timecapsule-samba-4.24.3/control/install-release.sh 4.24.3 \
    /Volumes/dk2/.samba/incoming/timecapsule-samba-4.24.3'
```

Installation creates a versioned release and updates the `current` symlink. It
does not start Samba or modify PF.

## 5. Provision and validate Samba

Create `tcbackup` as a persistent, non-root Unix service account using the
mechanism supported by the inspected firmware. Do not use `root` or blindly
edit an ephemeral `/etc/passwd`. Then create its Samba password interactively:

```sh
$TC_SSH '/mnt/Flash/samba/bin/provision-smb-user.sh tcbackup'
$TC_SSH '/mnt/Flash/samba/bin/start-samba.sh'
```

Before redirecting client traffic, verify on the device:

```sh
$TC_SSH 'netstat -an | grep 1445; ps aux | grep "[s]mbd"; \
  tail -100 /Volumes/dk2/.samba/state/log/smbd.*.log 2>/dev/null || true'
```

Stop if configuration validation fails, a required VFS module is missing, the
disk unmounts, or `smbd` consumes enough memory to destabilize the firmware.

## 6. Activate client traffic

Back up `/etc/pf.conf`. Add reviewed declarations for the dedicated
`timecapsule-samba` translation/filter anchor in the correct sections of the
existing PF configuration, then validate the complete file with `pfctl -nf`.
Do not replace unrelated Apple rules.

Once the anchor is present, activate the redirect using the LAN interface found
during preflight:

```sh
$TC_SSH '/mnt/Flash/samba/bin/activate-samba.sh <LAN_INTERFACE>'
```

From two Macs running macOS 11 or newer:

1. Connect to `smb://$TC_HOST/Files` and verify create/read/rename/delete.
2. Select `TimeMachine` in Time Machine settings and enable backup encryption.
3. Run two backups concurrently for at least 30 minutes.
4. Restore a sample file from each Mac.
5. Confirm existing Apple disk mounting and AFP behavior still work.
6. Confirm `_smb._tcp` and `_adisk._tcp` are advertised. If the target cannot
   advertise them through Samba or its existing mDNS responder, document the
   manual SMB-mount setup and do not claim automatic Time Machine discovery.

Do not add persistence until these tests pass.

## 7. Persistence and rollback

Use only the persistent startup mechanism confirmed during preflight. Its
launcher must perform these operations in order:

1. Wait for `/Volumes/dk2/ShareRoot`.
2. Run `/mnt/Flash/samba/bin/start-samba.sh`.
3. Confirm port 1445 is listening.
4. Run `activate-samba.sh` with the recorded LAN interface.

Reboot and repeat share discovery, concurrent backup resumption, memory, and
restore checks. If any check fails, roll back immediately:

```sh
$TC_SSH '/mnt/Flash/samba/bin/rollback-samba.sh'
```

Rollback flushes only the dedicated PF anchor, stops replacement Samba, and
restores the previous release symlink. Remove the custom startup invocation
before the next reboot. Apple services are never disabled by these scripts.
