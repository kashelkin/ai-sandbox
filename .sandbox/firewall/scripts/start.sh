#!/bin/bash

set -e

bash /firewall/init.sh

touch /tmp/firewall-ready
echo "Firewall ready."

tail -f /dev/null
