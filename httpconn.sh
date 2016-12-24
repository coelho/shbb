HTTP_PATH=$1
HTTP_REMOTE_IP=$TCPREMOTEIP

declare -r request_uuid=`uuidgen`
declare -r request_tmp="/tmp/shbb/$request_uuid"
declare -r request_tmp_body="$request_tmp/body"
declare -r request_tmp_to_source="$request_tmp/to_source"

declare request_type
declare request_url
declare -A request_url_params
declare request_http_version
declare -A request_headers
declare -A response_headers
declare -a response_codes=(
	[200]="OK"
	[400]="Bad Request"
	[403]="Forbidden"
	[404]="Not Found"
	[405]="Method Not Allowed"
	[500]="Internal Server Error"
)

tmp_make() {
	mkdir -p "$request_tmp"
	trap tmp_rm EXIT
}

tmp_rm() {
	rm -rf "$request_tmp"
}

debug() {
	>&2 echo "$*"
}

read_line() {
	read -r line
	line=${line%%$'\r'}
	echo $line
}

read_request_headers() {
	local line=$(read_line)
	if [[ "$line" =~ ^([A-Z]*)[[:space:]](.*)[[:space:]]([a-zA-Z0-9/\.]*)$ ]]; then
		request_type=${BASH_REMATCH[1]}
		request_url=${BASH_REMATCH[2]}
		request_url=${request_url//[^a-zA-Z0-9_~\-\.\/\?&=]/}
		if [ $request_url == *".."* ]; then
			serve_error 400
			exit 0
		fi
		request_http_version=${BASH_REMATCH[3]}
	else
		serve_error 400
		exit 0
	fi
	if [[ $request_url =~ ^(.*)\?(.*)$ ]]; then
		request_url=${BASH_REMATCH[1]}
		local params=${BASH_REMATCH[2]}
		for i in ${params//&/ }; do
			if [[ "$i" =~ ^(.*)=(.*)$ ]]; then
				request_url_params[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
			fi
		done
	fi
	while true; do
		# FIXME: sanity limits on how many headers we accept
		local line=$(read_line)
		if [[ -z $line ]]; then
			break
		fi
		if [[ "$line" =~ ^([a-zA-Z0-9\-]*):[[:space:]](.*)$ ]]; then
			request_headers[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}
		else
			serve_error 400
			exit 0
		fi
	done

}

write_line() {
	printf '%s\r\n' "$*"
}

write_response_headers() {
	local response_code=$1
	local response_date=$(date +"%a, %d %b %Y %H:%M:%S %Z")
	if ! test "${response_headers['Server']+isset}"; then
		response_headers["Server"]="shbb"
	fi
	if ! test "${response_headers['Date']+isset}"; then
		response_headers["Date"]=$response_date
	fi
	if ! test "${response_headers['Expires']+isset}"; then
		response_headers["Expires"]=$response_date
	fi
	write_line "HTTP/1.0 $response_code ${response_codes[$response_code]}"
	for response_key in ${!response_headers[@]}; do
		write_line "$response_key: ${response_headers[$response_key]}"
	done
	write_line ""
}

serve() {
	local serve_path="$HTTP_PATH/$request_url"
	if [ ! -e $serve_path ]; then
		serve_error_verbose 404
		exit 0
	fi
	if [ -d $serve_path ]; then
		serve_dir "$serve_path"
	else
		serve_file "$serve_path"
	fi

}

serve_dir() {
	local serve_dir=$1
	if [ -f "$serve_dir/index.html" ]; then
		serve_file "$serve_dir/index.html"
	elif [ -f "$serve_dir/index.sh" ]; then
		serve_file "$serve_dir/index.sh"
	else
		serve_error_verbose 403
		exit 0
	fi
}

serve_file() {
	local serve_file=$1
	while [[ $serve_file == *"//"* ]]; do
		serve_file=${serve_file//\/\//\/}
	done
	if [[ "$serve_file" == *".sh" ]]; then
		response_headers["Content-Type"]="text/html"
		tmp_make
		HTTP_REMOTE_IP=$HTTP_REMOTE_IP 								\
		HTTP_PATH=$serve_file 										\
		HTTP_REQUEST_URL=$request_url								\
		HTTP_REQUEST_URL_PARAMS=$(declare -p request_url_params)	\
		HTTP_REQUEST_TYPE=$request_type								\
		HTTP_REQUEST_VERSION=$request_http_version					\
		HTTP_REQUEST_HEADERS=$(declare -p request_headers)	 		\
		HTTP_RESPONSE_HEADERS=$(declare -p response_headers)		\
			$SHELL "$serve_file" > "$request_tmp_body"				\
			3>"$request_tmp_to_source"
		if [ -f "$request_tmp_to_source" ]; then
			source "$request_tmp_to_source"
		fi
		debug "bash $request_type \"$request_url\" remote: $HTTP_REMOTE_IP path: \"$serve_file\" tmp: \"$request_tmp\""
		serve_file=$request_tmp_body
	elif [[ $request_type != "GET" ]]; then
		serve_error_verbose 405
		exit 0
	else
		response_headers["Content-Type"]=$(file -b --mime-type "$serve_file")
	fi
	local serve_file_size=$(stat -f%z "$serve_file" 2>/dev/null || stat --printf="%s" "$serve_file" 2>/dev/null)
	response_headers["Content-Length"]=$serve_file_size
	write_response_headers 200
	cat "$serve_file"
	debug "file $request_type \"$request_url\" remote: $HTTP_REMOTE_IP path: \"$serve_file\" size: $serve_file_size"
}

serve_error() {
	local response_code=$1
	response_headers["Content-Type"]="text/html"
	write_response_headers $response_code
	write_line "<h1>$response_code</h1>"
}

serve_error_verbose() {
	local response_code=$1
	debug "$response_code $request_type \"$request_url\" remote: $HTTP_REMOTE_IP"
	serve_error $response_code
}

read_request_headers
serve
