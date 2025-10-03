#!/bin/sh
set -eu

INSTALL=0
ARCH=""
LIST=0
INCLUDE_PATTERNS=""
EXCLUDE_PATTERNS=""
INCLUDE_REGEX=""
EXCLUDE_REGEX=""

# parse args
while [ $# -gt 0 ]; do
    case "$1" in
        --install)
            INSTALL=1
            ;;
        --arch)
            shift
            [ $# -gt 0 ] || { echo "💣️ The option arch requires a value" >&2; exit 1; }
            ARCH=$1
            ;;
        --list)
            LIST=1
            ;;
        --include)
            shift
            [ $# -gt 0 ] || { echo "💣️ The option include requires a pattern" >&2; exit 1; }
            INCLUDE_PATTERNS="$INCLUDE_PATTERNS $1"
            ;;
        --exclude)
            shift
            [ $# -gt 0 ] || { echo "💣️ The option exclude requires a pattern" >&2; exit 1; }
            EXCLUDE_PATTERNS="$EXCLUDE_PATTERNS $1"
            ;;
        --include-regex)
            shift
            [ $# -gt 0 ] || { echo "💣️ The option include-regex requires a regex" >&2; exit 1; }
            INCLUDE_REGEX="$INCLUDE_REGEX $1"
            ;;
        --exclude-regex)
            shift
            [ $# -gt 0 ] || { echo "💣️ The option exclude-regex requires a regex" >&2; exit 1; }
            EXCLUDE_REGEX="$EXCLUDE_REGEX $1"
            ;;
        *)
            echo "usage: $0 [--install] [--list] [--arch <x86_64|aarch64>] [--include PAT] [--exclude PAT] [--include-regex REGEX] [--exclude-regex REGEX]" >&2
            exit 1
            ;;
    esac
    shift
done

# create cache directory
mkdir -p cache

# detect or use forced architecture
if [ -z "$ARCH" ]; then
    ARCH=$(uname -m)
fi

case "$ARCH" in
    x86_64|aarch64)
        echo "Architecture $ARCH is supported. Proceeding."
        ;;
    *)
        echo "💣️ Architecture $ARCH is not supported"
        exit 1
        ;;
esac

if [ "$INSTALL" -eq 1 ]; then
    command -v alien || { echo "💣Please install 'alien'. Aborting"; exit 10; }
fi

base_url="https://download.copr.fedorainfracloud.org/results/ryanabx/cosmic-epoch/fedora-43-$ARCH"
repodata_url="$base_url/repodata"

echo "Fetching contents of metadata directory:"
echo " $repodata_url"

# fetch directory HTML
directory_html=$(curl -fsSL "$repodata_url/")

# extract the primary.xml.gz filename
primary_xml_gz_file=$(echo "$directory_html" | grep -oE "[0-9a-f]+-primary.xml.gz" | head -n1 || true)

if [ -z "$primary_xml_gz_file" ]; then
    echo "💣️ Could not parse html directory listing"
    exit 1
fi

primary_xml_gz_url="$repodata_url/$primary_xml_gz_file"

echo "🎬️ Downloading primary XML metadata: $primary_xml_gz_url"

# choose decompression tool
if command -v gunzip >/dev/null 2>&1; then
    DECOMPRESS="gunzip"
elif command -v gzip >/dev/null 2>&1; then
    DECOMPRESS="gzip -d -c"
else
    echo "💣️Please install gunzip or gzip. Aborting"
    exit 1
fi

# fetch + parse metadata
curl -fsSL "$primary_xml_gz_url" | $DECOMPRESS | \
awk '
    /<package / { inpkg=1; name=""; href=""; ver=""; rel=""; }
    /<\/package>/ {
        if (inpkg) {
            if (name != "" && href != "") {
                pkgs[n]=name "|" ver "|" rel "|" href
                n++
            }
            inpkg=0
        }
    }
    inpkg {
        if ($0 ~ /<name>/) {
            gsub(/.*<name>|<\/name>.*/, "", $0)
            name=$0
        }
        if ($0 ~ /<location /) {
            match($0, /href="([^"]+)"/, arr)
            href=arr[1]
        }
        if ($0 ~ /<version /) {
            match($0, /ver="([^"]+)"/, arr1)
            if (arr1[1] != "") ver=arr1[1]
            match($0, /rel="([^"]+)"/, arr2)
            if (arr2[1] != "") rel=arr2[1]
        }
    }
    END {
        for (i=n-1; i>=0; i--) {
            print pkgs[i]
        }
    }
' | {
    seen_names=""
    filenames=""
    count=0

    while IFS="|" read -r name ver rel href; do
        # skip debug and src
        case "$name" in
            *debug*) continue ;;
        esac
        case "$href" in
            *src.rpm) continue ;;
        esac

        # include filter (glob)
        if [ -n "$INCLUDE_PATTERNS" ]; then
            ok=0
            for pat in $INCLUDE_PATTERNS; do
                case "$name" in $pat) ok=1 ;; esac
            done
            [ "$ok" -eq 1 ] || continue
        fi

        # exclude filter (glob)
        if [ -n "$EXCLUDE_PATTERNS" ]; then
            for pat in $EXCLUDE_PATTERNS; do
                case "$name" in $pat) continue 2 ;; esac
            done
        fi

        # include filter (regex)
        if [ -n "$INCLUDE_REGEX" ]; then
            ok=0
            for re in $INCLUDE_REGEX; do
                printf '%s\n' "$name" | grep -Eq "$re" && ok=1
            done
            [ "$ok" -eq 1 ] || continue
        fi

        # exclude filter (regex)
        if [ -n "$EXCLUDE_REGEX" ]; then
            for re in $EXCLUDE_REGEX; do
                if printf '%s\n' "$name" | grep -Eq "$re"; then
                    continue 2
                fi
            done
        fi

        # unique by name
        case " $seen_names " in
            *" $name "*) continue ;;
        esac
        seen_names="$seen_names $name"
        count=$((count + 1))

        filename=$(basename "$href")
        full_url="$base_url/$href"

        if [ "$LIST" -eq 1 ]; then
            echo "$name $ver-$rel -> $full_url"
            continue
        fi

        echo "Processing $name"
        if [ -f "cache/$filename" ]; then
            echo " 🐿️ Reusing cached $filename"
        else
            echo " 🏄️ Downloading $filename..."
            curl -fsSL "$full_url" -o "cache/$filename"
        fi
        filenames="$filenames cache/$filename"
    done

    if [ "$INSTALL" -eq 1 ] && [ -n "$filenames" ]; then
        echo " 👽️ Converting and installing packages: $filenames"
        sudo alien -d -i $filenames
    fi

    echo "Processed $count packages"
}
