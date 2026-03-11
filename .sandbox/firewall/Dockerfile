FROM ubuntu:22.04

RUN apt-get update -qq && \
  apt-get install -y -qq \
  iptables \
  ipset \
  curl \
  dnsutils \
  jq \
  aggregate \
  iproute2 \
  iputils-ping \
  dnsmasq && \
  rm -rf /var/lib/apt/lists/*

CMD ["sh", "/firewall/start.sh"]
