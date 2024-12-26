#!/bin/bash

set -Eeuo pipefail
#template adapted from https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038

print_usage() {
    cat <<EOF
Usage: arc [options] [files]

Move a file to a directory (archive) from where it may be restored later

Example: arc --archive-dir archive-tmp/ -c zstd my-file.txt my-dir/

Available options:
    -h, --help           Show this help message
    -u, --undo           Unarchive the file and move it to its original location, see below
    -l, --list           List archived files   
    -a, --archive-dir    Set the archive directory [default: ~/archive]
    -i, --install        Install the script globally (from GitHub)
    --install-path       Specify the install path  [default: /usr/local/bin]
    --uninstall          Uninstall the script
    
To undo a file, provide either the file name or the full archive path (to avoid collisions)

EOF
    exit 0
}

msg() {
    printf "%b\n" "${1-}" >&2
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    msg "$msg"
    exit "$code"
}

files=()      # use for getting file names or relative paths
files_path=() # use for anything else, because it provides the full path

archive_dir=$(realpath ~/archive)
compression="" # take a file and output
install_path="/usr/local/bin"
is_undo=0

parse_options() {
    while :; do
        case "${1-}" in
        -h | --help)
            print_usage
            ;;
        --install-path)
            install_path="${2-}"
            shift
            ;;
        -i | --install)
            install
            ;;
        --uninstall)
            uninstall
            ;;
        -u | --undo)
            is_undo=1
            ;;
        -a | --archive-dir)
            if [ -d "${2-}" ]; then
                archive_dir="${2-}"
                archive_dir="$(realpath "${archive_dir%/}")"
                shift
            else
                die "Invalid archive directory" 4
            fi
            ;;
        -l | --list)
            list
            ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    files=("$@")

    for file in "${files[@]}"; do
        # are we in undo mode
        if [ $is_undo -eq 1 ]; then
            # is only the name provided?
            if [ "$(find "$archive_dir" -name "$file.*" 2>/dev/null | wc -l)" -eq 1 ]; then
                # expand the name to the absolute path and add it to the files_path list
                files_path+=("$(realpath "$(find "$archive_dir" -name "$file.*")")")
            else
                # if it is not the name, then it must be the path
                if [ ! -e "$archive_dir$file" ]; then
                    die "Invalid file given" 3 # if it doesn't even exist, exit
                fi
                files_path+=("$(realpath "$archive_dir$file")")
            fi
        else
            # we're not in undo mode, check if the path is valid
            if [ ! -e "$file" ]; then
                die "Invalid file given" 3
            fi

            # check if we're not trying to archive something inside "$archive_dir"
            if [[ "$(realpath "$file")" == "$archive_dir/"* ]]; then
                die "You cannot archive something inside the archive itself!" 5
            fi

            files_path+=("$(realpath "$file")")
        fi
    done

    [[ ${#files[@]} -eq 0 ]] && print_usage

    return 0
}

install() {
    if hash curl &>/dev/null; then
        sudo curl -so "$install_path"/arc https://raw.githubusercontent.com/turtureanu/arc.sh/main/arc.sh
    elif hash wget &>/dev/null; then
        sudo wget -qO "$install_path"/arc https://raw.githubusercontent.com/turtureanu/arc.sh/main/arc.sh
    else
        die "Neither curl nor wget is available. Install manually." 2
    fi

    if [ -f "$install_path/arc" ]; then
        sudo chmod +x "$install_path/arc"
        die "Install successful" 0
    else
        die "Couldn't download script. Install manually." 2
    fi
}

uninstall() {
    if [ -f "$install_path/arc" ]; then
        sudo rm "$install_path/arc"
    else
        if hash arc; then
            location="$(which arc)"
            sudo rm "$(which arc)"
            die "Removed arc.sh from $location" 0
        else
            die "Couldn't find arc.sh in $install_path or PATH" 1
        fi
    fi
}

list() {
    printf "size%-1s  date added%-10s  file name%-11s  original path\n\n" "" "" ""
    max_length=20 # max file name length

    find "$archive_dir/" -name "*.tar.gz" -exec bash -c '
        for file; do
            size=$(du -h "$file" | cut -f1) # display file size
            timestamp=$(date -d @"$(stat -c "%X" "$file")" "+%Y-%m-%d %H:%M:%S") # custom timestamp
            basename=$(basename -s ".tar.gz" "$file") # get the file name
            if [ ${#basename} -gt '"$max_length"' ]; then
                basename="${basename:0:'"$max_length"' - 3}..." # truncate the file name and add elipsis
            fi
            realpath=$(realpath "$file" | sed "s/\.tar\.gz//") # the path of the archived file
            printf "\033[0;34m%-5s\033[0m  \033[0;32m%-20s\033[0m  %-20s  %s\n" "$size" "$timestamp" "$basename" "$realpath"
        done
    ' _ {} + | sed "s|$archive_dir||" # get rid of the $archive_dir part of the path name to display the original path

    exit 0
}

undo() {
    for file in "${files_path[@]}"; do
        echo "$file"
        cd "$(dirname "$file")"
        # --absolute-names: clever little trick to use path stored inside the archive
        tar --absolute-names -xzf "$file"
    done
    exit 0
}

archive() {
    for file in "${files_path[@]}"; do
        # check if the user supplied the compression command
        if [ -z "$compression" ]; then
            # if they didn't, try using pigz
            if hash pigz 2>/dev/null; then
                compression="tar --absolute-names --use-compress-program='pigz -N -M --best' -cvf '${file}.tar.gz' '${file}'"
            else # fallback to gzip
                compression="tar --absolute-names -cvzf '${file}.tar.gz' '${file}'"
            fi
        fi

        eval "$compression 1> /dev/null"
        rm "$file"
        local FILE_PATH
        FILE_PATH="$archive_dir$(dirname "$file")"
        mkdir -p "$FILE_PATH" && mv "${file}.tar.gz" "$FILE_PATH"
    done

    return 0
}

parse_options "$@"

if [ $is_undo -eq 0 ]; then
    echo "hello"
    archive
else
    undo
fi

exit 0
