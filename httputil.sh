declare -r remote_ip=$HTTP_REMOTE_IP
declare -r request_type=$HTTP_REQUEST_TYPE
declare -r request_path=$HTTP_REQUEST_PATH
declare -r request_http_version=$HTTP_REQUEST_VERSION
eval $HTTP_REQUEST_HEADERS
eval $HTTP_RESPONSE_HEADERS
declare -A request_cookies

debug() {
	>&2 echo "$*"
}

header() {
	response_headers[$1]=$2
}

header_flush() {
	# FIXME: can't have two of the same header due to using an assoc array
	>&3 echo "$(declare -p response_headers)"
}

cookie() {
	# FIXME: sanitize the key/value
	local key=$1
	local value=$2
	local extra=$3
	if [[ -z $extra ]]; then
		header "Set-Cookie" "$key=$value"
	else
		header "Set-Cookie" "$key=$value; $extra"
	fi
}

cookie_parse() {
	local cookie_header=${request_headers["Cookie"]}
	if [[ -z $cookie_header ]]; then
		return 0
	fi
	request_cookies=()
	for i in ${cookie_header//; / }; do
		if [[ "$i" =~ ^(.*)=(.*)$ ]]; then
			request_cookies[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
		fi
	done
}

trap header_flush EXIT
cookie_parse
