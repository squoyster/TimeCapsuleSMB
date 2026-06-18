#!/bin/sh
set -eu

DISK_ROOT=/Volumes/dk2/.samba
CURRENT=$DISK_ROOT/current
CONFIG=/mnt/Flash/samba/etc/smb.conf
SMBD=$CURRENT/samba-min/sbin/smbd
TESTPARM=$CURRENT/samba-min/bin/testparm
PIDFILE=$DISK_ROOT/state/run/smbd.pid

waited=0
while test ! -d /Volumes/dk2/ShareRoot && test "$waited" -lt 120; do
    sleep 5
    waited=$((waited + 5))
done
test -d /Volumes/dk2/ShareRoot || { echo 'data disk did not mount within 120 seconds' >&2; exit 1; }
test -x "$SMBD" || { echo "missing executable: $SMBD" >&2; exit 1; }
test -f "$CONFIG" || { echo "missing configuration: $CONFIG" >&2; exit 1; }

export LD_LIBRARY_PATH="$CURRENT/lib:$CURRENT/samba-min/lib"
if test -x "$TESTPARM"; then
    "$TESTPARM" -s "$CONFIG" >/dev/null
fi
if test -f "$PIDFILE" && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo 'Samba is already running.'
    exit 0
fi

"$SMBD" -D -s "$CONFIG"
sleep 2
netstat -an | grep -E '[.:]1445[[:space:]].*LISTEN' >/dev/null || {
    echo 'smbd did not listen on port 1445' >&2
    exit 1
}
echo 'Samba is listening on port 1445. PF has not been changed.'
