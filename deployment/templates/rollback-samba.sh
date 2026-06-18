#!/bin/sh
set -eu

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

DISK_ROOT=/Volumes/dk2/.samba
ANCHOR=timecapsule-samba
PIDFILE=$DISK_ROOT/state/run/smbd.pid

pfctl -a "$ANCHOR" -F all 2>/dev/null || true
if test -f "$PIDFILE"; then
    pid=$(cat "$PIDFILE")
    kill "$pid" 2>/dev/null || true
fi

if test -f "$DISK_ROOT/previous-release"; then
    previous_version=$(cat "$DISK_ROOT/previous-release")
    previous=$DISK_ROOT/releases/$previous_version
    if test -d "$previous"; then
        rm -f "$DISK_ROOT/current.rollback"
        ln -s "$previous" "$DISK_ROOT/current.rollback"
        mv -f "$DISK_ROOT/current.rollback" "$DISK_ROOT/current"
        echo "$previous_version" > "$DISK_ROOT/current-version"
        echo "Restored release symlink to $previous"
    fi
fi
echo 'Replacement Samba stopped and its PF anchor flushed; Apple services were not changed.'
