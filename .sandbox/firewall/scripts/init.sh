#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# 1. Extract Docker DNS info BEFORE any flushing
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# Flush existing rules and delete existing ipsets
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# 2. Selectively restore ONLY internal Docker DNS resolution
# Create ipset with CIDR support
if [ -n "$DOCKER_DNS_RULES" ]; then
  echo "Restoring Docker DNS rules..."
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  while IFS= read -r rule; do
    if ! eval iptables -t nat "$rule" 2>/dev/null; then
      echo "WARNING: Failed to restore rule: $rule"
    fi
  done <<<"$DOCKER_DNS_RULES"
else
  echo "No Docker DNS rules to restore"
fi

ipset create allowed-domains hash:net

# Start dnsmasq
echo "Starting dnsmasq..."
pkill dnsmasq 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf
sleep 1

# Verify dnsmasq is running
if ! pgrep dnsmasq >/dev/null; then
  echo "ERROR: dnsmasq failed to start"
  exit 1
fi

# Point container DNS to dnsmasq so ipset gets populated on every lookup
echo "nameserver 127.0.0.1" >/etc/resolv.conf

# Allow localhost and DNS first
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# Get host IP from default route
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
  echo "ERROR: Failed to detect host IP"
  exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j REJECT --reject-with icmp-admin-prohibited

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outbound to dynamically-populated ipset
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Reject everything else
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"

# Verification
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "ERROR: Firewall verification failed - was able to reach https://example.com"
  exit 1
else
  echo "Firewall verification passed - blocked https://example.com as expected"
fi

if ! curl --connect-timeout 5 https://api.github.com/zen >/dev/null 2>&1; then
  echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
  exit 1
else
  echo "Firewall verification passed - able to reach https://api.github.com as expected"
fi

if ping -c 1 -W 3 "$HOST_IP" >/dev/null 2>&1; then
  echo "ERROR: Firewall verification failed - was able to reach host $HOST_IP"
  exit 1
else
  echo "Firewall verification passed - unable to reach host $HOST_IP as expected"
fi
