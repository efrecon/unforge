#!/bin/sh

# If editing from Windows. Choose LF as line-ending

set -eu

# Level of verbosity, the higher the more verbose. All messages are sent to the
# stderr.
UNGIT_VERBOSE=${UNGIT_VERBOSE:-0}

# UNGIT_TYPE can be set to either github or gitlab depending on the repository
# type. The default is to detect from the URL and when not possible, defaults to
# github.
UNGIT_TYPE=${UNGIT_TYPE:-}

# Default reference to use when none is specified.
UNGIT_DEFAULT_REF=${UNGIT_DEFAULT_REF:-main}

# Force overwriting of existing files and directories.
UNGIT_FORCE=${UNGIT_FORCE:-0}

# Keep the content of the target directory as is before extracting. Usually,
# this is just a bad idea. So it exists as a variable-driven option only.
UNGIT_KEEP=${UNGIT_KEEP:-0}

# Protect target directory and files from being changed by making them
# read-only.
UNGIT_PROTECT=${UNGIT_PROTECT:-0}

# Print usage out of content of main script and exit.
usage() {
  # This uses the comments behind the options to show the help. Not extremly
  # correct, but effective and simple.
  if [ -z "${USAGE:-}" ]; then
    USAGE="Extract/maintain snapshots of git(hub/lab) repositories"
  fi
  printf "%s: %s\\n" "$(basename "$0")" "$USAGE" && \
    grep -E '^\s+[[:alnum:]])\s+#' "$0" |
    sed 's/#//' |
    sed -E 's/([[:alnum:]])\)/-\1\t/'
  printf \\nEnvironment:\\n
  set | grep '^UNGIT_' | sed 's/^UNGIT_/    UNGIT_/g'
  exit "${1:-0}"
}


while getopts "fpr:t:vh-" opt; do
  case "$opt" in
    f) # Force overwriting of existing files and directories
      UNGIT_FORCE=1;;
    p) # Protect target directory and files from being changed by making them read-only
      UNGIT_PROTECT=1;;
    r) # Set the default reference, main by default
      UNGIT_DEFAULT_REF=$OPTARG;;
    t) # Force the repository type (github or gitlab), empty to autodetect from URL. Defaults to github
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
  download_gz "${REPO_URL%/}/-/archive/${REPO_REF}/${REPO_NAME}-$(to_filename "${REPO_REF}").tar.gz" "${1:-}"
}

to_filename() {
  if [ $# -eq 0 ]; then
    tr -C '[:alnum:].:_' '-'
  else
    printf %s "$1" | to_filename
  fi
}

# At least a repository name is required.
if [ $# -eq 0 ]; then
  usage 1>&2
fi

# If the first argument is a URL, use it as is, otherwise construct the full URL
if printf %s\\n "$1" | grep -qE '^https?://'; then
  REPO_URL=$1
else
  case "$UNGIT_TYPE" in
    gitlab)
      REPO_URL=https://gitlab.com/$1;;
    *)
      REPO_URL=https://github.com/$1;;
  esac
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
if [ -d "$DESTDIR" ]; then
  if [ "$UNGIT_PROTECT" -eq 1 ]; then
    chmod -R u-w "$DESTDIR"
  fi
  if [ "$UNGIT_KEEP" -eq 1 ]; then
    verbose "Extracting $UNGIT_TYPE snapshot to ${DESTDIR}, directory content will be entirely replaced."
  else
    verbose "Extracting $UNGIT_TYPE snapshot to ${DESTDIR}, current directory content kept."
    rm -rf "$DESTDIR"
  fi
fi
mkdir -p "${DESTDIR}"
tar -C "${tardir}/${REPO_NAME}-$(to_filename "${REPO_REF}")" -cf - . | tar -C "${DESTDIR}" -xf -
if [ "$UNGIT_PROTECT" -eq 1 ]; then
  chmod -R a-w "$DESTDIR"
fi

# Cleanup.
rm -rf "$dwdir" "$tardir"
