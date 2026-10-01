#!/usr/bin/env bash
#
# install-python.sh — build and install CPython from python.org source into /usr/local
#
# Usage:
#   ./install-python.sh python3.X.Y   # install exactly that version
#   ./install-python.sh python3.X     # install the latest released 3.X.Y
#
# Any existing /usr/local/bin/python3.X is overwritten in place ("make altinstall"),
# so pip-installed packages and virtual environments for 3.X keep working.
# Other versions (and the generic "python3" link) are left untouched.
#
# Environment overrides:
#   FORCE=1   rebuild even if the requested version is already installed
#
set -euo pipefail

PREFIX="/usr/local"
DEFAULT_CONFIGURE_ARGS=(--prefix="$PREFIX" --enable-optimizations --enable-shared)
FTP="https://www.python.org/ftp/python"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") python3.X.Y | python3.X

  python3.X.Y   install that exact version (e.g. python3.12.15)
  python3.X     install the latest released version of 3.X (e.g. python3.12)
EOF
  exit 1
}

# ---------------------------------------------------------------- parse input
[[ $# -eq 1 ]] || usage
arg="${1#python}"   # accept "python3.12.15" (and also plain "3.12.15")

if [[ $arg =~ ^3\.([0-9]+)\.([0-9]+)$ ]]; then
  minor="3.${BASH_REMATCH[1]}"
  version="$arg"
elif [[ $arg =~ ^3\.([0-9]+)$ ]]; then
  minor="$arg"
  version=""
else
  usage
fi

# ---------------------------------------------------------------- privileges
if [[ $EUID -eq 0 ]]; then
  SUDO=""
else
  command -v sudo >/dev/null || die "sudo is required to install into $PREFIX"
  SUDO="sudo"
fi

command -v curl >/dev/null || die "curl is required (e.g. sudo apt install curl)"

# ---------------------------------------------------------------- resolve version
tarball_url() { echo "$FTP/$1/Python-$1.tar.xz"; }

latest_version() {
  local listing v
  listing=$(curl -fsSL "$FTP/") || die "Could not fetch the release list from $FTP/"
  # Directories like 3.12.15/ — newest first. Some directories only hold
  # pre-releases (e.g. 3.15.0/ before final), so check the final tarball exists.
  while read -r v; do
    [[ -n $v ]] || continue
    if curl -fsIL -o /dev/null "$(tarball_url "$v")"; then
      echo "$v"
      return 0
    fi
  done < <(grep -oE 'href="[0-9]+\.[0-9]+\.[0-9]+/"' <<<"$listing" \
             | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
             | awk -F. -v m="$minor" '($1 "." $2) == m' \
             | sort -Vru)
  return 1
}

if [[ -z $version ]]; then
  info "Looking up the latest Python $minor release..."
  version=$(latest_version) || die "No released version of Python $minor found on python.org"
fi

url=$(tarball_url "$version")
curl -fsIL -o /dev/null "$url" || die "Python $version not found ($url)"

# ---------------------------------------------------------------- current install
bin="$PREFIX/bin/python$minor"
current=""
if [[ -x $bin ]]; then
  current=$("$bin" -c 'import platform; print(platform.python_version())' 2>/dev/null || true)
fi

if [[ -n $current && $current == "$version" && ${FORCE:-0} != 1 ]]; then
  info "Python $version is already installed at $bin — nothing to do (set FORCE=1 to rebuild)."
  exit 0
fi

# Reuse the configure flags of the existing install, so the rebuild matches it.
configure_args=("${DEFAULT_CONFIGURE_ARGS[@]}")
if [[ -n $current ]]; then
  existing=()
  mapfile -d '' -t existing < <("$bin" -c 'import shlex, sys, sysconfig; sys.stdout.write("\0".join(shlex.split(sysconfig.get_config_var("CONFIG_ARGS") or "")))' 2>/dev/null || true)
  if [[ ${#existing[@]} -gt 0 ]]; then
    configure_args=("${existing[@]}")
  fi
fi

if [[ -n $current ]]; then
  info "Replacing Python $current with Python $version at $bin"
else
  info "Installing Python $version to $bin"
fi
info "Configure options: ${configure_args[*]}"

# ---------------------------------------------------------------- build dependencies
info "Installing build dependencies..."
if command -v apt-get >/dev/null; then
  $SUDO apt-get update
  $SUDO apt-get install -y build-essential pkg-config libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses-dev libffi-dev liblzma-dev libgdbm-dev \
    libgdbm-compat-dev uuid-dev tk-dev libzstd-dev xz-utils
elif command -v dnf >/dev/null; then
  $SUDO dnf install -y gcc make pkgconf-pkg-config openssl-devel zlib-devel bzip2-devel \
    readline-devel sqlite-devel ncurses-devel libffi-devel xz-devel gdbm-devel \
    libuuid-devel tk-devel libzstd-devel tar xz
else
  warn "Unknown package manager — make sure the build dependencies are installed yourself."
fi

for tool in gcc make tar; do
  command -v "$tool" >/dev/null || die "$tool is required but not installed"
done

# ---------------------------------------------------------------- download & build
workdir=$(mktemp -d -t python-build-XXXXXX)
cleanup() {
  local status=$?
  if [[ $status -eq 0 ]]; then
    rm -rf "$workdir"
  else
    warn "Build failed — build files kept in $workdir for inspection."
  fi
}
trap cleanup EXIT

info "Downloading $url"
curl -fL --progress-bar -o "$workdir/Python-$version.tar.xz" "$url"
tar -xf "$workdir/Python-$version.tar.xz" -C "$workdir"
cd "$workdir/Python-$version"

info "Configuring..."
./configure "${configure_args[@]}"

info "Building with $(nproc) jobs (--enable-optimizations runs the test suite for PGO; this takes a while)..."
make -j"$(nproc)"

info "Installing (make altinstall)..."
$SUDO make altinstall

# Needed with --enable-shared so the new libpython is picked up.
$SUDO ldconfig

# ---------------------------------------------------------------- verify
installed=$("$bin" -c 'import platform; print(platform.python_version())' 2>/dev/null) \
  || die "$bin does not run — if it complains about libpython, check that $PREFIX/lib is in /etc/ld.so.conf.d/ and rerun 'sudo ldconfig'."
[[ $installed == "$version" ]] || die "Expected $version but $bin reports $installed"

if "$bin" -c 'import ssl, sqlite3, lzma, bz2, zlib, ctypes, readline, uuid' 2>/dev/null; then
  info "Standard library modules check passed."
else
  warn "Some optional modules are missing (a -dev package was absent during the build)."
  warn "Run: $bin -c 'import ssl, sqlite3, lzma, bz2, zlib, ctypes, readline, uuid' to see which."
fi

info "Done: $("$bin" --version) installed at $bin"