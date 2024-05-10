# DDNS Name und Gateway
# usage dynroute.sh ddnsname yourgatewayrouter
# assuming a shutdown after usage, old routes will "not" be deleted
DDNS_HOSTNAME=$1
GATEWAY=$2

#DNS via One
ip route add 1.1.1.1 via 192.168.66.1
echo "nameserver 1.1.1.1" > /etc/resolv.conf

# ddns auflösen
CURRENT_IP=$(dig +short $DDNS_HOSTNAME)
if [[ -z "$CURRENT_IP" ]]; then
    echo "Failed to resolve IP for $DDNS_HOSTNAME"
    exit 1
fi
# route setzen
ip route add  $CURRENT_IP via $GATEWAY
