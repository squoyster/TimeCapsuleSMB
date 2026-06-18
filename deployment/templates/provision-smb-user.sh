#!/bin/sh
set -eu

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

USER_NAME=${1:-root}
CURRENT=/Volumes/dk2/.samba/current
SMBPASSWD=$CURRENT/samba-min/bin/smbpasswd

user_exists=false
while IFS=: read -r name _rest; do
    if test "$name" = "$USER_NAME"; then
        user_exists=true
        break
    fi
done < /etc/passwd
test "$user_exists" = true || {
    echo "Unix account '$USER_NAME' does not exist." >&2
    echo 'Create a persistent, non-root service account supported by this firmware before continuing.' >&2
    exit 1
}
test -x "$SMBPASSWD" || {
    echo "Missing smbpasswd in the deployment bundle: $SMBPASSWD" >&2
    exit 1
}

echo "Creating or updating Samba identity '$USER_NAME'."
echo 'The password is read interactively and is not placed in argv or logs.'
LD_LIBRARY_PATH="$CURRENT/lib:$CURRENT/samba-min/lib" \
    "$SMBPASSWD" -c /Volumes/dk2/.samba/control/smb.conf -a "$USER_NAME"
