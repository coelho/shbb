HTTP_BIND_IP=$1
HTTP_BIND_PORT=$2
HTTP_PATH=$3
>&2 echo "starting http server on $HTTP_BIND_IP:$HTTP_BIND_PORT path: $HTTP_PATH"
tcpserver $HTTP_BIND_IP $HTTP_BIND_PORT $SHELL ./httpconn.sh "$HTTP_PATH"

