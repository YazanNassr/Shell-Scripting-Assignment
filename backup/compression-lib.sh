compress_file() {
     pigz "$1"
     mv "$1.gz" "$1" 
}

decompress_archive() {
     mv "$1" "${1}.gz"
    pigz -d "${1}.gz"
}

encrypt_file() {
	# file=$1		passphrase=$2
	gpg --batch --yes --symmetric --passphrase "$2" "$1"
	mv "${1}.gpg" "$1"
}

decrypt_file() {
	# file=$1		passphrase=$2
	mv "$1" "${1}.gpg" 
	gpg --batch --yes --passphrase "$2" --decrypt "${1}.gpg" 1>$1 2>/dev/null
	rm "${1}.gpg" 
}
