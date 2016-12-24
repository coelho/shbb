declare -r remote_ip=$HTTP_REMOTE_IP
declare -r request_type=$HTTP_REQUEST_TYPE
declare -r request_path=$HTTP_REQUEST_PATH
declare -r request_http_version=$HTTP_REQUEST_VERSION
eval $HTTP_REQUEST_HEADERS
eval $HTTP_RESPONSE_HEADERS

debug() {
	>&2 echo "$*"
}

header() {
	response_headers[$1]=$2
}

header_flush() {
	>&3 echo "$(declare -p response_headers)"
}

trap header_flush EXIT
