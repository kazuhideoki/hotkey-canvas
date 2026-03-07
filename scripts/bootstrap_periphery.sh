#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
periphery_version="3.6.0"
periphery_sha256="983cb6bad09b7030f0ec151e05f650dbf450eb624bd361a0ad89c59fdbf18182"
periphery_url="https://github.com/peripheryapp/periphery/releases/download/${periphery_version}/periphery-${periphery_version}.zip"
install_dir="${repo_root}/.tools/periphery/${periphery_version}"
binary_path="${install_dir}/periphery"

if [[ -x "${binary_path}" ]]; then
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required to bootstrap Periphery." >&2
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "error: unzip is required to bootstrap Periphery." >&2
    exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

archive_path="${tmp_dir}/periphery.zip"
extract_dir="${tmp_dir}/extract"

mkdir -p "${install_dir}" "${extract_dir}"

curl -fsSL "${periphery_url}" -o "${archive_path}"
echo "${periphery_sha256}  ${archive_path}" | shasum -a 256 -c >/dev/null
unzip -q "${archive_path}" -d "${extract_dir}"

resolved_binary="$(find "${extract_dir}" -type f -name periphery -perm -111 | head -n 1)"

if [[ -z "${resolved_binary}" ]]; then
    echo "error: failed to locate the Periphery binary in ${periphery_url}." >&2
    exit 1
fi

install -m 755 "${resolved_binary}" "${binary_path}"
