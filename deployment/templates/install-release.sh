#!/bin/sh
set -eu

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

VERSION=${1:?usage: install-release.sh VERSION BUNDLE_ROOT}
BUNDLE_ROOT=${2:?usage: install-release.sh VERSION BUNDLE_ROOT}
DISK_ROOT=/Volumes/dk2/.samba
RELEASE=$DISK_ROOT/releases/$VERSION
CONTROL=$DISK_ROOT/control

test -d /Volumes/dk2/ShareRoot || {
    echo '/Volumes/dk2/ShareRoot is not mounted; leave Apple File Sharing enabled' >&2
    exit 1
}
test -x "$BUNDLE_ROOT/runtime/samba-min/sbin/smbd" || {
    echo 'bundle does not contain an executable smbd' >&2
    exit 1
}
test -f "$BUNDLE_ROOT/control/smb.conf" || {
    echo 'bundle does not contain smb.conf' >&2
    exit 1
}
test ! -e "$RELEASE" || {
    echo "release already exists: $RELEASE" >&2
    exit 1
}

mkdir -p \
    "$DISK_ROOT/releases" \
    "$DISK_ROOT/state/cache" \
    "$DISK_ROOT/state/lock" \
    "$DISK_ROOT/state/log" \
    "$DISK_ROOT/state/private" \
    "$DISK_ROOT/state/run" \
    "$CONTROL"

cp -Rp "$BUNDLE_ROOT/runtime" "$RELEASE"
cp "$BUNDLE_ROOT/control/smb.conf" "$CONTROL/smb.conf.new"
for script in activate-samba.sh provision-smb-user.sh rollback-samba.sh start-samba.sh; do
    cp "$BUNDLE_ROOT/control/$script" "$CONTROL/$script"
    chmod 700 "$CONTROL/$script"
done

if test -f "$DISK_ROOT/current-version"; then
    cp "$DISK_ROOT/current-version" "$DISK_ROOT/previous-release"
fi
rm -f "$DISK_ROOT/current.new"
ln -s "$RELEASE" "$DISK_ROOT/current.new"
mv -f "$DISK_ROOT/current.new" "$DISK_ROOT/current"
echo "$VERSION" > "$DISK_ROOT/current-version"
mv -f "$CONTROL/smb.conf.new" "$CONTROL/smb.conf"

echo "Installed Samba $VERSION but did not start it or change packet-filter rules."
echo "Next: provision the SMB user, then run $CONTROL/start-samba.sh"
