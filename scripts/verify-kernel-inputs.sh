#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
misc_root="$(cd "${script_dir}/.." && pwd)"
android_root="$(cd "${misc_root}/../../.." && pwd)"
lock_file="${misc_root}/manifests/m9.731-kernel-inputs.env"
verify_outputs=0
failures=0

usage() {
  cat <<'EOF'
Usage: verify-kernel-inputs.sh [--android-root DIR] [--with-current-outputs]

Checks the frozen M9.731 GKI, device/vendor revisions, configuration inputs,
toolchain revision, UAPI archive, DTB/DTBO and retained manifest. The optional
output check also verifies the current generated .config and Image.
EOF
}

while (($#)); do
  case "$1" in
    --android-root)
      android_root="$(cd "${2:?missing directory}" && pwd)"
      shift 2
      ;;
    --with-current-outputs)
      verify_outputs=1
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

# shellcheck disable=SC1090
source "${lock_file}"

pass() {
  printf 'PASS %-28s %s\n' "$1" "$2"
}

fail() {
  printf 'FAIL %-28s %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

check_sha() {
  local label="$1" expected="$2" path="$3" observed
  if [[ ! -f "${path}" ]]; then
    fail "${label}" "missing=${path}"
    return
  fi
  observed="$(sha256sum "${path}" | awk '{print $1}')"
  if [[ "${observed}" == "${expected}" ]]; then
    pass "${label}" "sha256=${observed}"
  else
    fail "${label}" "expected=${expected} observed=${observed} path=${path}"
  fi
}

check_git_revision() {
  local label="$1" expected="$2" path="$3" observed
  if [[ ! -d "${path}/.git" && ! -f "${path}/.git" ]]; then
    fail "${label}" "missing_git_repo=${path}"
    return
  fi
  observed="$(git -C "${path}" rev-parse HEAD)"
  if [[ "${observed}" == "${expected}" ]]; then
    pass "${label}" "commit=${observed}"
  else
    fail "${label}" "expected=${expected} observed=${observed}"
  fi
}

compute_worktree_tree() {
  local worktree="$1" temporary_git observed_tree
  temporary_git="$(mktemp -d)"
  git --git-dir="${temporary_git}" --work-tree="${worktree}" init -q
  GIT_INDEX_FILE="${temporary_git}/index" \
    git --git-dir="${temporary_git}" --work-tree="${worktree}" add -f -A
  observed_tree="$(GIT_INDEX_FILE="${temporary_git}/index" \
    git --git-dir="${temporary_git}" --work-tree="${worktree}" write-tree)"
  rm -rf -- "${temporary_git}"
  printf '%s\n' "${observed_tree}"
}

gki_dir="${android_root}/${GKI_SOURCE_PATH}"
if [[ ! -d "${gki_dir}/.git" && ! -f "${gki_dir}/.git" ]]; then
  if [[ ! -d "${gki_dir}" ]]; then
    fail gki_tree "missing_source_tree=${gki_dir}"
  else
    gki_tree="$(compute_worktree_tree "${gki_dir}")"
    if [[ "${gki_tree}" == "${GKI_TREE}" ]]; then
      pass gki_identity "mode=archive tree=${gki_tree}"
      pass gki_worktree archive_tree_verified
    else
      fail gki_identity "mode=archive expected_tree=${GKI_TREE} observed_tree=${gki_tree}"
    fi
  fi
else
  gki_commit="$(git -C "${gki_dir}" rev-parse HEAD)"
  gki_tree="$(git -C "${gki_dir}" rev-parse 'HEAD^{tree}')"
  if [[ "${gki_commit}" == "${GKI_COMMIT}" && "${gki_tree}" == "${GKI_TREE}" ]]; then
    pass gki_identity "commit=${gki_commit} tree=${gki_tree}"
  else
    fail gki_identity "commit=${gki_commit} tree=${gki_tree}"
  fi
  if [[ -z "$(git -C "${gki_dir}" status --porcelain --untracked-files=all)" ]]; then
    pass gki_worktree clean
  else
    fail gki_worktree dirty
  fi
fi

check_sha gki_defconfig "${GKI_DEFCONFIG_SHA256}" \
  "${gki_dir}/${GKI_DEFCONFIG_PATH}"
check_git_revision device_revision "${DEVICE_COHERENT_COMMIT}" \
  "${android_root}/${DEVICE_REPO_PATH}"
check_git_revision vendor_revision "${VENDOR_COMMIT}" \
  "${android_root}/${VENDOR_REPO_PATH}"
check_sha config_fragment "${CONFIG_FRAGMENT_SHA256}" \
  "${android_root}/${CONFIG_FRAGMENT_PATH}"
check_sha reference_config "${REFERENCE_CONFIG_SHA256}" \
  "${misc_root}/${REFERENCE_CONFIG_PATH}"
check_sha uapi_archive "${UAPI_ARCHIVE_SHA256}" \
  "${misc_root}/${UAPI_ARCHIVE_PATH}"
check_sha installed_uapi "${UAPI_ARCHIVE_SHA256}" \
  "${android_root}/${UAPI_INSTALL_PATH}"
check_sha dtb "${DTB_SHA256}" "${android_root}/${DTB_PATH}"
check_sha dtbo "${DTBO_SHA256}" "${android_root}/${DTBO_PATH}"
check_sha repo_manifest "${REPO_MANIFEST_SHA256}" \
  "${misc_root}/${REPO_MANIFEST_PATH}"
check_git_revision clang_revision "${CLANG_REPO_COMMIT}" \
  "${android_root}/${CLANG_REPO_PATH}"
check_git_revision build_tools_revision "${BUILD_TOOLS_REPO_COMMIT}" \
  "${android_root}/${BUILD_TOOLS_REPO_PATH}"
check_git_revision kernel_tools_revision "${KERNEL_BUILD_TOOLS_REPO_COMMIT}" \
  "${android_root}/${KERNEL_BUILD_TOOLS_REPO_PATH}"

if [[ -x "${android_root}/${CLANG_DIR}/bin/clang" ]]; then
  pass clang_binary "path=${android_root}/${CLANG_DIR}/bin/clang"
else
  fail clang_binary "missing=${android_root}/${CLANG_DIR}/bin/clang"
fi
check_sha clang_binary_hash "${CLANG_BINARY_SHA256}" \
  "${android_root}/${CLANG_DIR}/bin/clang"
check_sha lld_binary_hash "${LLD_BINARY_SHA256}" \
  "${android_root}/${CLANG_DIR}/bin/ld.lld"
check_sha make_binary_hash "${MAKE_BINARY_SHA256}" \
  "${android_root}/${BUILD_TOOLS_REPO_PATH}/linux-x86/bin/make"
check_sha pahole_binary_hash "${PAHOLE_BINARY_SHA256}" \
  "${android_root}/${KERNEL_BUILD_TOOLS_REPO_PATH}/linux-x86/bin/pahole"

if (( verify_outputs )); then
  check_sha generated_config "${REFERENCE_CONFIG_SHA256}" \
    "${android_root}/${GENERATED_CONFIG_PATH}"
  check_sha generated_image "${REFERENCE_IMAGE_SHA256}" \
    "${android_root}/${GENERATED_IMAGE_PATH}"
fi

if (( failures != 0 )); then
  printf 'verify_kernel_inputs=fail failures=%d\n' "${failures}" >&2
  exit 1
fi

printf 'verify_kernel_inputs=pass failures=0 outputs_checked=%d\n' \
  "${verify_outputs}"
