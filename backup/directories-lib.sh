trim_empty_directories() {
    find $1 -empty -type d -delete
}

replicate_dir_tree() {
    directories=$(find "$@" -empty -type d)
    for directory in $directories ; do
        mkdir -p "$root/$directory"
    done
}
