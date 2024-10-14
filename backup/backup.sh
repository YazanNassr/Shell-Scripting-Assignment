#!/bin/bash

. database-management-lib.sh
. hashing-lib.sh
. directories-lib.sh
. compression-lib.sh

root=""
filesdir=""

display_usage() {
	echo "Usage: backup.sh mode args"
	echo "  modes and args:"
	echo "    backup  | update  src...             dest"
	echo "    encrypt | decrypt passpharse         dest"
	echo "    stats   | clean | compress | extract dest"
	exit $1
}

validate_arguments_count() {
	if [ $# -le $1 ] ; then
		display_usage 1
	fi
}

validate_is_directory() {
	if [ ! -d "$1" ] ; then
		display_usage 2
	fi
}

database_config() {
	if [ -z "$donedbconfigflag" ] ; then
		par_path="${1}/${par_path}"
		db_init
		donedbconfigflag="done"
	fi
}

backupfile() {
	file="$1"

	digest=$(hash_file "$file")

	creation_date="$(db_get_creation_date $digest)"

	if [ -z "$creation_date" ] ; then
		cp "$file" "$filesdir/$digest"
		db_add_file $digest
	fi

	if [ -e "$root/$file" ] ; then
		rm "$root/$file"
		db_rem_path "$file"
	fi

	mkdir -p "$root/$(dirname $file)"
	ln "$filesdir/$digest" "$root/$file"

	db_add_path $digest "$file"
}

backup() {
	validate_arguments_count 2 "$@"

	root=${@: $#}	srcs="${@: 1 : $(expr $#-1)}"

	validate_is_directory "$root"

	database_config $root

	db_log_message "starting a backup" 

	filesdir="${root}/.data/files"
	mkdir -p $filesdir

	files="$(find $srcs -type f)"

	IFS_OLD="$IFS"
	IFS=$'\n'
	for file in $files ; do 
		backupfile "$file"
	done
	IFS=$IFS_OLD

	trim_empty_directories $root
	replicate_dir_tree $srcs

	db_log_message "backing up finished" 
}

clean_filestree() {
	root="$1"

	database_config $root

	db_log_message "clearing files tree" 

	bkfiles="$(find $root -type d -name '.data' -prune -o -type f -print)"

	for file in $bkfiles ; do
		rm "$file"
		db_rem_path "${file#$root/}"
	done

	trim_empty_directories $root

	db_log_message "files tree cleared" 
}

update() {
	validate_arguments_count 2 "$@"
	
	root=${@: $#}

	validate_is_directory "$root"

	clean_filestree $root

	backup "$@"
}

clean_unreferenced_files() {
	validate_arguments_count 1 "$@"

	root=$1

	validate_is_directory "$root"

	filesdir="${root}/.data/files"

	database_config $root

	db_log_message "cleaning up unreferenced files"

	files="$(db_get_files)"

	for file in $files ; do
		if [ -z "$(db_get_paths $file)" ] ; then
			rm "$filesdir/$file"
			db_rem_file $file
		fi
	done

	db_log_message "clean up finished"
}


compress() {
	validate_arguments_count 2 "$@"

	root=$1		mode=$2
	filesdir="${root}/.data/files"

	validate_is_directory "$root"

	database_config $root

	db_log_message "starting compression operation"

	files="$(db_get_files)"

	for file in $files ; do
		id_enc="$(db_get_id_encryption "$file")"
		id="$(db_get_id_compression "$file")"

		if [ -n "$id_enc" -o "$mode" = "c" -a -n "$id" -o "$mode" = "x" -a -z "$id" ] ; then
			continue;
		fi

		paths=$(db_get_paths "$file")

		IFS_OLD="$IFS"
		IFS=$'\n'
		for path in $paths ; do
			rm "${root}/${path}"
			db_rem_path "$path"
		done

		if [ "$mode" = "c" ] ; then
			compress_file "$filesdir/$file"
			db_add_compressed "$file" "$(hash_file "${filesdir}/$file")"
		elif [ "$mode" = "x" ] ; then
			decompress_archive "$filesdir/$file"
			db_rem_compressed "$file"
		fi

		for path in $paths ; do
			ln "${filesdir}/$file" "${root}/${path}"
			db_add_path "$file" "$path"
		done
		IFS=$IFS_OLD
	done

	db_log_message "finished compression operation"
}

encrypt() {
	validate_arguments_count 3 "$@"

	passphrase="$1"		root="$2"		mode="$3" 

	filesdir="${root}/.data/files"

	validate_is_directory "$root"

	database_config "$root"

	db_log_message "started encryption operation"

	files="$(db_get_files)"

	for file in $files ; do
		id="$(db_get_id_encryption "$file")"

		if [ "$mode" = "e" -a -n "$id" -o "$mode" = "d" -a -z "$id" ] ; then
			continue;
		fi

		paths=$(db_get_paths "$file")

		IFS_OLD="$IFS"
		IFS=$'\n'
		for path in $paths ; do
			rm "${root}/${path}"
			db_rem_path "$path"
		done

		if [ "$mode" = "e" ] ; then
			encrypt_file "$filesdir/$file" "$passphrase"
			db_add_encrypted "$file" "$(hash_file "${filesdir}/$file")"
		elif [ "$mode" = "d" ] ; then
			decrypt_file "$filesdir/$file" "$passphrase"
			db_rem_encrypted "$file"
		fi

		for path in $paths ; do
			ln "${filesdir}/$file" "${root}/${path}"
			db_add_path "$file" "$path"
		done
		IFS="$IFS_OLD"
	done

	db_log_message "finished encryption operation"
}	

display_stats() {
	validate_arguments_count 1 "$@"
	root=$1
	validate_is_directory "$root"
	filesdir="${root}/.data/files"

	num_of_files="$(ls $filesdir | wc -l)"
	size_of_backup_image="$(du -c -h $filesdir | tail -n 1 | cut -f 1)"
	
	echo "You have $num_of_files unique file(s) in your backup image"
	echo "Your backup image size is $size_of_backup_image"
}

if [ "$BASH_SOURCE" = "$0" ] ; then
	validate_arguments_count 1 "$@"

	mode="$1"
	shift 1

	case $mode in
		"backup"   ) backup "$@"          		;;
		"update"   ) update "$@"          		;;
		"clean"    ) clean_unreferenced_files "$@"     	;;
		"compress" ) compress "$@" "c"    		;;
		"extract"  ) compress "$@" "x"  		;;
		"encrypt"  ) encrypt "$@" "e"    		;;
		"decrypt"  ) encrypt "$@" "d"  			;;
		"stats"    ) display_stats "$@"   		;;
		*          ) echo "Unknown operation";
				   display_usage 1		;;
	esac
fi
