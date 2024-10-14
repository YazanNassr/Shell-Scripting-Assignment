par_path=".data"
backup_db_name="metadata.db"
log_file_name="logs.txt"
backup_db="${par_path}/${backup_db_name}"
log_file="${par_path}/${log_file_name}"

db_init() {
    mkdir -p $par_path
    backup_db="${par_path}/${backup_db_name}"
    log_file="${par_path}/${log_file_name}"
    touch "$log_file"
    
    # Note I always do compression before encryption
    sqlite3 $backup_db "CREATE TABLE IF NOT EXISTS files(id TEXT PRIMARY KEY, creation_date TEXT);"
    sqlite3 $backup_db "CREATE TABLE IF NOT EXISTS paths(id TEXT, path TEXT, CONSTRAINT path_pk PRIMARY KEY (id, path), FOREIGN KEY(id) REFERENCES files(id));"
    sqlite3 $backup_db "CREATE TABLE IF NOT EXISTS compression(id TEXT PRIMARY KEY, digest_aft TEXT);"
    sqlite3 $backup_db "CREATE TABLE IF NOT EXISTS encryption(id TEXT PRIMARY KEY, digest_aft TEXT);"

    # sqlite3 $backup_db "CREATE INDEX id ON files (id)"
}

db_add_file() {
    digest=$1
    date=$(date --rfc-3339 d)
    sqlite3 $backup_db "INSERT INTO files VALUES('"$digest"', '"$date"');"
}

db_rem_file() {
    sqlite3 $backup_db "DELETE FROM files WHERE id='"$1"';"
}

db_get_files() {
    res=$(sqlite3 $backup_db "SELECT id FROM files;")
    echo "$res"
}

db_add_path() {
    digest=$1	path=$2
    sqlite3 $backup_db "INSERT INTO paths VALUES('"$digest"', '"$path"');"
}

db_rem_path() {
    sqlite3 $backup_db "DELETE FROM paths WHERE path='"$1"';"
}

db_get_paths() {
    res=$(sqlite3 $backup_db "SELECT path FROM paths WHERE id='"$1"';")
    echo "$res"
}

db_get_creation_date() {
    res=$(sqlite3 $backup_db "SELECT creation_date FROM files WHERE id='"$1"';")
    echo "$res"
}

db_get_id() {
    table=$1	column=$2	value=$3
    res=$(sqlite3 $backup_db "SELECT id FROM $table WHERE $column = '"$value"';")
    echo "$res"
}

db_get_id_from_path() {
    echo $(db_get_id 'paths' 'path' $1)
}

db_get_id_compression() {
    echo $(db_get_id 'compression' 'id' $1)
}

db_add_compressed() {
    id=$1	digest=$2
    sqlite3 $backup_db "INSERT INTO compression VALUES('"$id"', '"$digest"');"
}

db_rem_compressed() {
    sqlite3 $backup_db "DELETE FROM compression WHERE id='"$1"';"
}

db_get_id_encryption() {
    echo $(db_get_id 'encryption' 'id' $1)
}

db_add_encrypted() {
    id=$1	digest=$2
    sqlite3 $backup_db "INSERT INTO encryption VALUES('"$id"', '"$digest"');"
}

db_rem_encrypted() {
    sqlite3 $backup_db "DELETE FROM encryption WHERE id='"$1"';"
}

db_log_message() {
	echo "$1"
	echo "$1 - $(date)" >> "$log_file"
}
