#!/bin/sh
set -e
mkdir -p /home/ansible/.ssh
echo "$PUBKEY" > /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys
exec /usr/sbin/sshd -D -e
