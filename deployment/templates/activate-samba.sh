#!/bin/sh
set -eu

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

LAN_IF=${1:?usage: activate-samba.sh LAN_INTERFACE}
ANCHOR=timecapsule-samba
RULES=/Volumes/dk2/.samba/control/pf-$ANCHOR.conf

port_1445_listening()
{
    listeners=$(netstat -an 2>/dev/null || true)
    case "$listeners" in
        *1445*LISTEN*) return 0 ;;
        *) return 1 ;;
    esac
}

anchor_present()
{
    rules=$(pfctl -sr 2>/dev/null || true)
    case "$rules" in
        *timecapsule-samba*) return 0 ;;
        *) return 1 ;;
    esac
}

ifconfig "$LAN_IF" >/dev/null 2>&1 || { echo "unknown interface: $LAN_IF" >&2; exit 1; }
port_1445_listening || {
    echo 'refusing redirect because Samba is not listening on port 1445' >&2
    exit 1
}
anchor_present || {
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
