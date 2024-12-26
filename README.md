# arc.sh

![logo](./logo.svg)

A useful BASH script that compresses and moves files to an "archive" directory, allowing you to restore them later to their original location.

```txt
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
    
To undo a file, provide either the file name or the full original path (to avoid collisions)
Examples:
    arc -u ".vsco*" # this will expand the glob pattern
    arc -u "/home/tux/projects/knowleaks/node_modules"
```

Made for [High Seas](https://highseas.hackclub.com/)