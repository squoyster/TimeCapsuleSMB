# Minimal Samba Deployment Runbook

The first deployment changes as little as possible. It runs Samba 4.24.3
manually on port 1445 against the existing `alex` share.

It does **not** change the existing data layout, write to `/mnt/Flash`, alter
PF, replace port 445, add a boot hook, create a Unix account, or enable Time
Machine-specific behavior. All new device files live under
`/Volumes/dk2/.samba` and can be removed together.

## 1. Inspect the device

Keep Apple File Sharing enabled and connect to the existing AFP share so the
firmware mounts `/Volumes/dk2`. Run the read-only probes:

```sh
export TC_HOST=airport-8tb.local
export TC_SSH='ssh -oHostKeyAlgorithms=+ssh-dss root@'"$TC_HOST"

$TC_SSH 'sh -s' < deployment/templates/preflight.sh
$TC_SSH 'sh -s' < deployment/templates/inspect-deployment-hooks.sh
```

Confirm the existing share directory and account before packaging. The current
defaults are based on the mounted AFP URL and are:

- Share name: `alex`
- Device path: `/Volumes/dk2/ShareRoot/alex`
- Existing Unix identity: `root`

Using `root` avoids creating a firmware account during the smoke test. The
Samba password is a separate record and should not reuse the device admin
password.

## 2. Build Samba 4.24.3

In the NetBSD cross-build VM, download Samba 4.24.3 and its detached signature
from Samba's official stable directory. Verify the signature before extracting
it. Prepare the NetBSD 6 `evbarm` cross-toolchain, the native build packages,
the staged target dependencies, and the reviewed Waf cross-answers:

```sh
export SAMBA_SOURCE=/root/tc-build/samba-4.24.3
export TOOLDIR=/root/netbsd6/usr/src/obj/tooldir.NetBSD-*
export SYSROOT=/root/netbsd6/usr/src/obj/destdir.evbarm
export TRIPLE=arm--netbsdelf-eabi
export CROSS_ANSWERS=/root/tc-build/netbsd-arm-4.24.3.txt
export PREFIX=/root/tc-stage-4.24.3
export JOBS=2

pkgin -y install pkgconf bison p5-Parse-Yapp
/path/to/TimeCapsuleSMB/building/build-prereqs.sh
/path/to/TimeCapsuleSMB/building/build-samba.sh
```

Stop if the maintained release does not build. Do not substitute the historical
Samba 4.8.12 output.

## 3. Package on the Mac

Copy the complete stage directory from the VM. Package it with the existing
share defaults:

```sh
python3 deploy.py package --stage /path/to/tc-stage-4.24.3
shasum -a 256 -c dist/timecapsule-samba-4.24.3.tar.gz.sha256
```

If inspection reports a different existing share, specify it without moving
anything:

```sh
python3 deploy.py package \
  --stage /path/to/tc-stage-4.24.3 \
  --share-name EXISTING_NAME \
  --share-path /Volumes/dk2/ShareRoot/EXISTING_DIRECTORY \
  --smb-user EXISTING_UNIX_USER
```

## 4. Copy and install without activation

The firmware has legacy `scp` but no `tar` or `gzip`. Extract locally, then copy
the directory recursively:

```sh
rm -rf dist/upload
mkdir -p dist/upload
tar xzf dist/timecapsule-samba-4.24.3.tar.gz -C dist/upload

$TC_SSH 'mkdir -p /Volumes/dk2/.samba/incoming'
scp -O -r -oHostKeyAlgorithms=+ssh-dss \
  dist/upload/timecapsule-samba-4.24.3 \
  root@"$TC_HOST":/Volumes/dk2/.samba/incoming/

$TC_SSH 'sh /Volumes/dk2/.samba/incoming/timecapsule-samba-4.24.3/control/install-release.sh 4.24.3 \
  /Volumes/dk2/.samba/incoming/timecapsule-samba-4.24.3'
```

This creates `/Volumes/dk2/.samba/releases/4.24.3`, state directories, a
`current` symlink, and control files. It does not start Samba.

## 5. Start and test on port 1445

Create a Samba-only password for the existing Unix identity. Do not reuse the
AirPort administrator password:

```sh
$TC_SSH '/Volumes/dk2/.samba/control/provision-smb-user.sh root'
$TC_SSH '/Volumes/dk2/.samba/control/start-samba.sh'
```

Verify that the original services remain on ports 445/548 and replacement
Samba listens separately on 1445:

```sh
$TC_SSH 'netstat -an; ps aux'
```

From the Mac, connect directly to the test port:

```sh
open 'smb://root@airport-8tb.local:1445/alex'
```

Verify listing, create, read, rename, and delete with disposable files. Monitor
`/Volumes/dk2/.samba/state/log` and device memory. Existing AFP access must
continue working throughout.

Stop the smoke-test server with:

```sh
$TC_SSH '/Volumes/dk2/.samba/control/rollback-samba.sh'
```

## Deferred changes

Only after the manual port-1445 test succeeds should a later phase consider:

- Redirecting port 445 or changing PF state.
- Automatic startup or `/mnt/Flash` files.
- A dedicated Unix/Samba account.
- Time Machine advertising, quotas, or a separate backup directory.
- Bonjour `_smb._tcp`/`_adisk._tcp` registration.
