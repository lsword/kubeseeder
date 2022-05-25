#!/bin/bash

ipvalid() {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)
  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done
  return 0
}

if [ $# -eq 1 ] && [ $1 == "master" ]; then
  mv /etc/chrony.conf /etc/chrony.conf.bak
cat > /etc/chrony.conf <<EOF
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
allow 0.0.0.0/0
local stratum 10
logdir /var/log/chrony
EOF

  systemctl restart chronyd
  chronyc sources -V

  exit 0
fi

if [ $# -eq 2 ] && [ $1 == "node" ]; then
  ipvalid $2
  if [ $? -ne 0 ];then
    echo "Invalid ip address"
    exit 1
  fi
   mv /etc/chrony.conf /etc/chrony.conf.bak
cat > /etc//chrony.conf <<EOF
server $2 iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

  systemctl restart chronyd
  chronyc sources -V

  exit 0
fi

echo "Usage: timesync.sh <master>"
echo "       timesync.sh <node> <masterip>"
exit 1
