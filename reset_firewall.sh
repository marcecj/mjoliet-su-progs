#!/bin/sh

iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -t nat -F
iptables -t nat -X
iptables -t nat -P OUTPUT ACCEPT
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t mangle -F
iptables -t mangle -X
iptables -t mangle -P INPUT ACCEPT
iptables -t mangle -P OUTPUT ACCEPT
iptables -t mangle -P FORWARD ACCEPT
iptables -t mangle -P PREROUTING ACCEPT
iptables -t mangle -P POSTROUTING ACCEPT
