#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
misc_root="$(cd "${script_dir}/.." && pwd)"
android_root="$(cd "${misc_root}/../../.." && pwd)"
lock_file="${misc_root}/manifests/m9.731-kernel-inputs.env"

# shellcheck disable=SC1090
source "${lock_file}"

install_input=0

usage() {
  cat <<'EOF'
Usage: install-misc-inputs.sh [--android-root DIR] [--install]

Without --install this is a read-only plan/check. With --install it copies the
locked UAPI archive only when the destination is absent. A differing existing
file is never overwritten.
EOF
}

while (($#)); do
  case "$1" in
    --android-root)
      android_root="$(cd "${2:?missing directory}" && pwd)"
      shift 2
      ;;
    --install)
      install_input=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

source_file="${misc_root}/${UAPI_ARCHIVE_PATH}"
destination="${android_root}/${UAPI_INSTALL_PATH}"
source_sha="$(sha256sum "${source_file}" | awk '{print $1}')"
if [[ "${source_sha}" != "${UAPI_ARCHIVE_SHA256}" ]]; then
  echo "error: repository UAPI archive does not match the lock" >&2
  exit 1
fi

if [[ -e "${destination}" ]]; then
  destination_sha="$(sha256sum "${destination}" | awk '{print $1}')"
  if [[ "${destination_sha}" != "${UAPI_ARCHIVE_SHA256}" ]]; then
    echo "error: refusing to overwrite differing input: ${destination}" >&2
    exit 1
  fi
  printf 'install_misc_inputs=pass state=already_present path=%s\n' "${destination}"
  exit 0
fi

if (( ! install_input )); then
  printf 'install_misc_inputs=plan source=%s destination=%s\n' \
    "${source_file}" "${destination}"
  exit 0
fi

mkdir -p "$(dirname "${destination}")"
install -m 0644 "${source_file}" "${destination}"
destination_sha="$(sha256sum "${destination}" | awk '{print $1}')"
if [[ "${destination_sha}" != "${UAPI_ARCHIVE_SHA256}" ]]; then
  echo "error: installed UAPI archive failed post-copy verification" >&2
  exit 1
fi
printf 'install_misc_inputs=pass state=installed path=%s\n' "${destination}"
