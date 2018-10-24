#!/bin/sh

if ! test -e /var/run/docker.sock; then
  echo "/var/run/docker.sock does not exist"
  exit 1
fi
addgroup --gid "`stat -c '%g' /var/run/docker.sock`" dockersock
usermod -a -G dockersock jenkins
touch /tmp/dockersock.test
chmod 440 /tmp/dockersock.test
chown root:dockersock /tmp/dockersock.test