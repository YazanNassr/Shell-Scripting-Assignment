hash_function="$(which sha256sum)"

hash_file() {
    file="$1"
    res=$($hash_function "$file" | cut -d ' ' -f 1)
    echo "$res"
}
