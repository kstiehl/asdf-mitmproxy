#!/usr/bin/env bash

set -euo pipefail

# This is the correct GitHub homepage where releases can be downloaded for mitmproxy.
GH_REPO="https://github.com/mitmproxy/mitmproxy"
TOOL_NAME="mitmproxy"
TOOL_TEST="mitmproxy --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if mitmproxy is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

get_platform() {
  local platform="linux"

  case "$(uname | tr '[:upper:]' '[:lower:]')" in
    darwin) platform="macos" ;;
  esac

  echo -n $platform
}

list_all_versions() {
  # Change this function if mitmproxy has other means of determining installable versions.
  list_github_tags
}

download_release() {
  local version filename url
  version="$1"
  filename="$2"
  platform=$(get_platform)

  # mitmproxy release URL
  url="https://downloads.mitmproxy.org/${version}/mitmproxy-${version}-${platform}.tar.gz"
  echo $url
  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path/bin"
    cp -R "$ASDF_DOWNLOAD_PATH/." "$install_path/bin"

    # Asert mitmproxy executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
