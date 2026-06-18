#!/bin/sh
set -u

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

echo '== data permissions =='
ls -land /Volumes/dk2 /Volumes/dk2/ShareRoot /mnt/Flash 2>&1 || true

echo '== local accounts =='
cat /etc/passwd 2>&1 || true

echo '== service supervision =='
for path in /var/sv /var/sv/* /service /service/*; do
    test -e "$path" && ls -lad "$path"
done

echo '== boot configuration =='
for path in /etc/rc /etc/rc.local /etc/rc.conf /etc/rc.d /etc/rc.d/*; do
    test -e "$path" && ls -lad "$path"
done

echo '== packet-filter configuration =='
for path in /etc/pf.conf /mnt/Flash/pf.conf /mnt/Flash/*pf*; do
    if test -f "$path"; then
        echo "-- $path --"
        cat "$path"
    fi
done

echo '== deployment-related tools =='
for tool in adduser chmod chown dns-sd getextattr logger mDNSResponder pwd_mkdb setextattr svc svscan useradd vipw; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "$tool=$(command -v "$tool")"
    else
        echo "$tool=MISSING"
    fi
done
