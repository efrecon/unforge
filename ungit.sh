#!/bin/sh

# If editing from Windows. Choose LF as line-ending

set -eu

# Find out where dependent modules are and load them at once before doing
# anything. This is to be able to use their services as soon as possible.

# This is a readlink -f implementation so this script can (perhaps) run on MacOS
abspath() {
  is_abspath() {
    case "$1" in
      /* | ~*) true;;
      *) false;;
    esac
  }

  if [ -d "$1" ]; then
    ( cd -P -- "$1" && pwd -P )
  elif [ -L "$1" ]; then
    if is_abspath "$(readlink "$1")"; then
      abspath "$(readlink "$1")"
    else
      abspath "$(dirname "$1")/$(readlink "$1")"
    fi
  else
    printf %s\\n "$(abspath "$(dirname "$1")")/$(basename "$1")"
  fi
}

UNGIT_ROOTDIR=$( cd -P -- "$(dirname -- "$(command -v -- "$(abspath "$0")")")" && pwd -P )


# Level of verbosity, the higher the more verbose. All messages are sent to the
# stderr.
UNGIT_VERBOSE=${UNGIT_VERBOSE:-0}

# UNGIT_TYPE can be set to either github or gitlab depending on the repository
# type. The default is to detect from the URL.
UNGIT_TYPE=${UNGIT_TYPE:-}

# URL to the default forge when none is specified. This is used to construct the
# full URL to the repository.
UNGIT_DEFAULT_FORGE=${UNGIT_DEFAULT_FORGE:-https://github.com}

# Default reference to use when none is specified.
UNGIT_DEFAULT_REF=${UNGIT_DEFAULT_REF:-main}

# Force overwriting of existing files and directories.
UNGIT_FORCE=${UNGIT_FORCE:-0}

# Print usage out of content of main script and exit.
usage() {
  # This uses the comments behind the options to show the help. Not extremly
  # correct, but effective and simple.
  if [ -z "${USAGE:-}" ]; then
    USAGE="Extract/maintain snapshots of git(hub/lab) repositories"
  fi
  printf "%s: %s\\n" "$(basename "$0")" "$USAGE" && \
    grep "[[:space:]]\-.*)\ #" "$0" |
    sed 's/#//' |
    sed 's/)/\t/'
  printf \\nEnvironment:\\n
  set | grep '^UNGIT_' | sed 's/^UNGIT_/    UNGIT_/g'
  exit "${1:-0}"
}


while getopts "fg:r:t:vh-" opt; do
  case "$opt" in
    f) # Force overwriting of existing files and directories
      UNGIT_FORCE=1;;
    g) # Set the URL to the default forge, https://github.com by default
      UNGIT_DEFAULT_FORGE=$OPTARG;;
    r) # Set the default reference, main by default
      UNGIT_DEFAULT_REF=$OPTARG;;
    t) # Force the repository type, leave empty to autodetect
      UNGIT_TYPE=$OPTARG;;
    v) # Increase verbosity
      UNGIT_VERBOSE=$((UNGIT_VERBOSE+1));;
    h)
      usage;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


# PML: Poor Man's Logging
_log() {
    printf '[%s] [%s] [%s] %s\n' \
      "$(basename "$0")" \
      "${2:-LOG}" \
      "$(date +'%Y%m%d-%H%M%S')" \
      "${1:-}" \
      >&2
}
trace() { if [ "${UNGIT_VERBOSE:-0}" -ge "3" ]; then _log "$1" TRC; fi; }
debug() { if [ "${UNGIT_VERBOSE:-0}" -ge "2" ]; then _log "$1" DBG; fi; }
verbose() { if [ "${UNGIT_VERBOSE:-0}" -ge "1" ]; then _log "$1" NFO; fi; }
warning() { _log "$1" WRN; }
error() { _log "$1" ERR && exit 1; }

# Download the url passed as the first argument to the destination path passed
# as a second argument. The destination will be the same as the basename of the
# URL, in the current directory, if omitted.
download() {
  debug "Downloading $1 to ${2:-$(basename "$1")}"
  if command -v curl >/dev/null; then
    curl -sSL -o "${2:-$(basename "$1")}" "$1"
  elif command -v wget >/dev/null; then
    wget -q -O "${2:-$(basename "$1")}" "$1"
  else
    error "You need curl or wget installed to download files!\n"
  fi
}

download_gz() {
  download "$@"
  if [ -f "${2:-$(basename "$1")}" ]; then
    if ! gzip -t "${2:-$(basename "$1")}" 1>/dev/null 2>&1; then
      trace "Downloaded file ${2:-$(basename "$1")} is not a valid gzip file. Removing it."
      rm -f "${2:-$(basename "$1")}"
      return 1
    fi
  else
    return 1
  fi
}

download_github_archive() {
  download_gz "${REPO_URL%/}/archive/refs/heads/${REPO_REF}.tar.gz" "${1:-}" ||
    download_gz "${REPO_URL%/}/archive/refs/tags/${REPO_REF}.tar.gz" "${1:-}" ||
    download_gz "${REPO_URL%/}/archive/${REPO_REF}.tar.gz" "${1:-}"
}

download_gitlab_archive() {
  download_gz "${REPO_URL%/}/-/archive/${REPO_REF}/${REPO_NAME}-${REPO_REF}.tar.gz" "${1:-}"
}

# At least a repository name is required.
if [ $# -eq 0 ]; then
  usage 1>&2
fi

# If the first argument is a URL, use it as is, otherwise construct the full URL
if printf %s\\n "$1" | grep -qE '^https?://'; then
  REPO_URL=$1
else
  REPO_URL=${UNGIT_DEFAULT_FORGE%/}/$1
fi
shift

# Extract the tag, branch or commit reference as being everything after the @
REPO_REF=$(printf %s\\n "$REPO_URL" | grep -oE '@.*$' | cut -c 2-)
if [ -z "$REPO_REF" ]; then
  REPO_REF=$UNGIT_DEFAULT_REF
else
  REPO_URL=$(printf %s\\n "$REPO_URL" | sed 's/@.*$//')
fi

# Decide the destination directory. Construct a directory under the current one
# using the base name of the repository if none is specified.
REPO_NAME=${REPO_URL##*/}
if [ $# -eq 0 ]; then
  DESTDIR=$(pwd)/$REPO_NAME
else
  DESTDIR=$1
fi
if [ -d "$DESTDIR" ] && [ "$UNGIT_FORCE" -eq 0 ]; then
  error "Destination directory $DESTDIR already exists. Use -f to overwrite."
fi

# Decide the repository type when none is specified, detect from the URL
if [ -z "$UNGIT_TYPE" ]; then
  if printf %s\\n "$REPO_URL" | grep -q 'github\.com'; then
    UNGIT_TYPE=github
  elif printf %s\\n "$REPO_URL" | grep -q 'gitlab\.com'; then
    UNGIT_TYPE=gitlab
  else
    error "Unsupported repository type: $REPO_URL"
  fi
fi
verbose "Downloading and extracting $UNGIT_TYPE repository at ${REPO_URL}@${REPO_REF} into $DESTDIR"

# Download the tarball to a temporary directory and extract it to another
# temporary directory.
dwdir=$(mktemp -d)
if "download_${UNGIT_TYPE}_archive" "${dwdir}/${REPO_NAME}.tar.gz"; then
  debug "Downloaded ${REPO_URL}@${REPO_REF} to ${REPO_NAME}.tar.gz"
else
  rm -rf "$dwdir";  # Cleanup and exit
  error "Could not download ${REPO_URL}@${REPO_REF} to ${REPO_NAME}.tar.gz"
fi

tardir=$(mktemp -d)
mkdir -p "$tardir"
tar -xzf "${dwdir}/${REPO_NAME}.tar.gz" -C "$tardir"

# Create the destination directory and copy the contents of the tarball to it.
mkdir -p "${DESTDIR}"
verbose "Extracting GitHub snapshot to ${DESTDIR}"
tar -C "${tardir}/${REPO_NAME}-${REPO_REF}" -cf - . | tar -C "${DESTDIR}" -xf -

# Cleanup.
rm -rf "$dwdir" "$tardir"
