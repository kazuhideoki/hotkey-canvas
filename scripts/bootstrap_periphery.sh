#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
periphery_version="3.6.0"
periphery_sha256="983cb6bad09b7030f0ec151e05f650dbf450eb624bd361a0ad89c59fdbf18182"
periphery_url="https://github.com/peripheryapp/periphery/releases/download/${periphery_version}/periphery-${periphery_version}.zip"
install_dir="${repo_root}/.tools/periphery/${periphery_version}"
binary_path="${install_dir}/periphery"
binary_checksum_path="${install_dir}/periphery.sha256"
print_binary_path=false

if [[ "${1:-}" == "--print-binary-path" ]]; then
    print_binary_path=true
fi

compute_file_sha256() {
    shasum -a 256 "$1" | awk '{ print $1 }'
}

is_installed_binary_valid() {
    if [[ ! -x "${binary_path}" ]]; then
        return 1
    fi
    if [[ ! -f "${binary_checksum_path}" ]]; then
        return 1
    fi

    local expected_binary_sha256
    expected_binary_sha256="$(<"${binary_checksum_path}")"
    local current_binary_sha256
    current_binary_sha256="$(compute_file_sha256 "${binary_path}")"

    [[ "${current_binary_sha256}" == "${expected_binary_sha256}" ]]
}

if is_installed_binary_valid; then
    if ${print_binary_path}; then
        echo "${binary_path}"
    fi
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
compute_file_sha256 "${binary_path}" > "${binary_checksum_path}"

if ${print_binary_path}; then
    echo "${binary_path}"
fi
