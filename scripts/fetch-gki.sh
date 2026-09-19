#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
misc_root="$(cd "${script_dir}/.." && pwd)"
android_root="$(cd "${misc_root}/../../.." && pwd)"
lock_file="${misc_root}/manifests/m9.731-kernel-inputs.env"

# shellcheck disable=SC1090
source "${lock_file}"

destination="${android_root}/${GKI_SOURCE_PATH}"
source_url="${GKI_SOURCE_URL}"
archive=""

usage() {
  cat <<'EOF'
Usage: fetch-gki.sh [options]

Options:
  --android-root DIR  Android/Lineage source root.
  --destination DIR   Destination for the GKI source tree.
  --source-url URL    Git source URL; defaults to the locked AOSP URL.
  --archive FILE      Extract and verify the retained source archive instead
                      of fetching Git.
  -h, --help          Show this help.

The destination must not already exist. No existing tree is deleted or reset.
EOF
}

while (($#)); do
  case "$1" in
    --android-root)
      android_root="$(cd "${2:?missing directory}" && pwd)"
      destination="${android_root}/${GKI_SOURCE_PATH}"
      shift 2
      ;;
    --destination)
      destination="${2:?missing destination}"
      shift 2
      ;;
    --source-url)
      source_url="${2:?missing source URL}"
      shift 2
      ;;
    --archive)
      archive="${2:?missing archive}"
      shift 2
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

if [[ -e "${destination}" ]]; then
  echo "error: destination already exists: ${destination}" >&2
  exit 1
fi

mkdir -p "$(dirname "${destination}")"

if [[ -n "${archive}" ]]; then
  if [[ ! -f "${archive}" ]]; then
    echo "error: archive not found: ${archive}" >&2
    exit 1
  fi
  archive_sha="$(sha256sum "${archive}" | awk '{print $1}')"
  archive_size="$(stat -c %s "${archive}")"
  if [[ "${archive_sha}" != "${GKI_ARCHIVE_SHA256}" ||
        "${archive_size}" != "${GKI_ARCHIVE_SIZE}" ]]; then
    echo "error: archive size/hash does not match the lock" >&2
    exit 1
  fi

  mkdir -p "${destination}"
  tar -xzf "${archive}" -C "${destination}"

  temporary_git="$(mktemp -d)"
  cleanup() {
    rm -rf -- "${temporary_git}"
  }
  trap cleanup EXIT
  git --git-dir="${temporary_git}" --work-tree="${destination}" init -q
  GIT_INDEX_FILE="${temporary_git}/index" \
    git --git-dir="${temporary_git}" --work-tree="${destination}" add -f -A
  observed_tree="$(GIT_INDEX_FILE="${temporary_git}/index" \
    git --git-dir="${temporary_git}" --work-tree="${destination}" write-tree)"
  if [[ "${observed_tree}" != "${GKI_TREE}" ]]; then
    echo "error: extracted archive tree mismatch: ${observed_tree}" >&2
    exit 1
  fi
  printf 'fetch_gki=pass mode=archive destination=%s tree=%s\n' \
    "${destination}" "${observed_tree}"
  exit 0
fi

git init -q "${destination}"
git -C "${destination}" remote add origin "${source_url}"
git -C "${destination}" fetch --depth=1 origin \
  "refs/tags/${GKI_TAG}:refs/tags/${GKI_TAG}"
git -C "${destination}" checkout -q --detach "${GKI_COMMIT}"

observed_commit="$(git -C "${destination}" rev-parse HEAD)"
observed_tree="$(git -C "${destination}" rev-parse 'HEAD^{tree}')"
observed_tag_object="$(git -C "${destination}" rev-parse "${GKI_TAG}^{tag}")"
if [[ "${observed_commit}" != "${GKI_COMMIT}" ||
      "${observed_tree}" != "${GKI_TREE}" ||
      "${observed_tag_object}" != "${GKI_TAG_OBJECT}" ]]; then
  echo "error: fetched Git identity does not match the lock" >&2
  exit 1
fi

printf 'fetch_gki=pass mode=git destination=%s commit=%s tree=%s\n' \
  "${destination}" "${observed_commit}" "${observed_tree}"
