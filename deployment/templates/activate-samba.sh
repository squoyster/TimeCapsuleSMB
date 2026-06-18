#!/bin/sh
set -eu

LAN_IF=${1:?usage: activate-samba.sh LAN_INTERFACE}
ANCHOR=timecapsule-samba
RULES=/mnt/Flash/samba/etc/pf-$ANCHOR.conf

ifconfig "$LAN_IF" >/dev/null 2>&1 || { echo "unknown interface: $LAN_IF" >&2; exit 1; }
netstat -an | grep -E '[.:]1445[[:space:]].*LISTEN' >/dev/null || {
    echo 'refusing redirect because Samba is not listening on port 1445' >&2
    exit 1
}
pfctl -sr 2>/dev/null | grep -q "$ANCHOR" || {
    echo "PF does not contain a reviewed '$ANCHOR' anchor." >&2
    echo 'Add rdr-anchor/anchor declarations to the persistent PF configuration first.' >&2
    exit 1
}

cat > "$RULES.new" <<EOF
rdr pass on $LAN_IF proto tcp from any to any port 445 -> 127.0.0.1 port 1445
EOF
pfctl -n -a "$ANCHOR" -f "$RULES.new"
mv -f "$RULES.new" "$RULES"
pfctl -a "$ANCHOR" -f "$RULES"
echo "Redirected TCP 445 on $LAN_IF to Samba port 1445."
