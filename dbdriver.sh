if [ -z $DB_PATH ]; then
	DB_PATH="./db/"
fi

mkdir -p "$DB_PATH"
declare -A db_cursor
declare -A db_save
declare -A db_indexes

db_define() {
	local collection=$1
	mkdir -p "$DB_PATH/$collection/uuid/"
}

db_define_idx() {
	local collection=$1
	local index=$2
	mkdir -p "$DB_PATH/$collection/idx/$index"
	if ! test "${db_indexes[$collection]+isset}"; then
		db_indexes[$collection]=$index
	else
		local indexes=${db_indexes[$collection]}
		indexes+=","
		indexes+=$index
		db_indexes[$collection]=$indexes
	fi
}

db_insert() {
	local collection=$1
	local uuid=""
	if ! test "${db_cursor['uuid']+isset}"; then
		uuid=`uuidgen`
		db_cursor["uuid"]=$uuid
	else
		uuid=db_cursor["uuid"]
	fi
	db_clear_idx "$collection" "$index" "$uuid"
	db_save=()
	for i in "${!db_cursor[@]}"; do
		db_save[$i]=${db_cursor[$i]}
	done
	declare -p db_save > "$DB_PATH/$collection/uuid/$uuid"
	local indexes=${db_indexes[$collection]}
	for i in ${indexes//,/ }; do
		local i_value=${db_save[$i]}
		local i_path="$DB_PATH/$collection/idx/$i/$i_value"
		echo "$uuid" >> "$i_path"
	done
}

db_delete() {
	local collection=$1
	local index=$2
	local value=$3
	db_delete_one "$collection" "$index" "$value"
	if [[ $index == "uuid" ]]; then
		return $?
	fi
	if [[ $? != "0" ]]; then
		return $?
	fi
	while true; do
		db_delete_one "$collection" "$index" "$value"
		if [[ $? != "0" ]]; then
			return $?
		fi
	done
}

db_delete_one() {
	local collection=$1
	local index=$2
	local value=$3
	local uuid=""
	if [[ $index != "uuid" ]]; then
		uuid=$(tail -n 1 "$DB_PATH/$collection/idx/$index/$value" 2>/dev/null)
	fi
	if [ -z $uuid ]; then
		return 1
	fi
	db_clear_idx "$collection" "$index" "$uuid"
	rm -f "$DB_PATH/$collection/uuid/$uuid"
	return 0
}

db_clear_idx() {
	local collection=$1
	local index=$2
	local uuid=$3
	if [ ! -f "$DB_PATH/$collection/uuid/$uuid" ]; then
		return 0
	fi
	db_save=()
	source "$DB_PATH/$collection/uuid/$uuid" 2>/dev/null
	local indexes=${db_indexes[$collection]}
	for i in ${indexes//,/ }; do
		local i_value=${db_save[$i]}
		local i_path="$DB_PATH/$collection/idx/$i/$i_value"
		sed -i '' "/$uuid/d" "$i_path"
		if [ ! -s "$i_path" ]; then
			rm -f "$i_path"
		fi
	done
}

db_select_one() {
	local collection=$1
	local index=$2
	local value=$3
	local uuid=""
	if [[ $index != "uuid" ]]; then
		uuid=$(tail -n 1 "$DB_PATH/$collection/idx/$index/$value" 2>/dev/null)
	fi
	if [ -z $uuid ]; then
		return 1
	fi
	source "$DB_PATH/$collection/uuid/$uuid" 2>/dev/null
	db_cursor=()
	for i in "${!db_save[@]}"; do
		db_cursor[$i]=db_save[$i]
	done
	return 0
}

db_print_cursor() {
	declare -p db_cursor
}
