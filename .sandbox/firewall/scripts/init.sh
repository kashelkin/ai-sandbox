#!/bin/bash

set -euo pipefail

# 1. Snapshot Docker DNS NAT rules before flush
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
  if ! printf '*nat\n%s\nCOMMIT\n' "$DOCKER_DNS_RULES" | iptables-restore --noflush; then
    echo "ERROR: Failed to restore Docker DNS NAT rules — DNS resolution will not work"
    exit 1
  fi
else
  echo "No Docker DNS rules to restore"
fi

ipset create allowed-domains hash:net

# Start dnsmasq
echo "Starting dnsmasq..."
pkill dnsmasq 2>/dev/null || true
dnsmasq --conf-file=/etc/dnsmasq.conf

# Wait for dnsmasq to be ready by probing port 53
for i in $(seq 1 10); do
  if dig +short +time=1 @127.0.0.1 localhost >/dev/null 2>&1; then
    echo "dnsmasq is ready"
    break
  fi
  if [ "$i" -eq 10 ]; then
    echo "ERROR: dnsmasq did not become ready within 5 seconds"
    exit 1
  fi
  sleep 0.5
done

# Point container DNS to dnsmasq so ipset gets populated on every lookup
echo "nameserver 127.0.0.1" >/etc/resolv.conf

# Allow localhost and DNS first
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Get host IP from default route
HOST_IP=$(ip route show default | awk 'NR==1 {print $3}')
if [ -z "$HOST_IP" ]; then
  echo "ERROR: Failed to detect host IP"
  exit 1
fi

HOST_IFACE=$(ip route show default | awk 'NR==1 {print $5}')
HOST_NETWORK=$(ip -o -f inet addr show "$HOST_IFACE" | awk '{print $4}' | head -n1)
if [ -z "$HOST_NETWORK" ]; then
  echo "ERROR: Failed to detect host network for interface $HOST_IFACE"
  exit 1
fi
echo "Host network detected as: $HOST_NETWORK (via $HOST_IFACE)"

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outbound SSH
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow inbound from host network
iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT

# Allow outbound to dynamically-populated ipset
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

# Block outbound to host network and reject everything else
iptables -A OUTPUT -d "$HOST_NETWORK" -j REJECT --reject-with icmp-admin-prohibited
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# Set default policies to DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

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
