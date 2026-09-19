#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
misc_root="$(cd "${script_dir}/.." && pwd)"
android_root="$(cd "${misc_root}/../../.." && pwd)"
lock_file="${misc_root}/manifests/m9.731-kernel-inputs.env"
run_build=0
allow_existing_kernel_out=0
jobs=""
artifact_dir=""
min_free_bytes=42949672960
min_free_inodes=1000000

# shellcheck disable=SC1090
source "${lock_file}"

usage() {
  cat <<'EOF'
Usage: reproduce-kernel-image.sh [options]

Options:
  --android-root DIR            Android/Lineage source root.
  --plan                        Print the locked build plan (default).
  --build                       Run the host-only `m kernel` build.
  --allow-existing-kernel-out   Permit reuse of an existing KERNEL_OBJ tree.
  --artifact-dir DIR            Required evidence/output directory for --build.
  --min-free-bytes N            Recorded free-space floor (default 40 GiB).
  --min-free-inodes N           Recorded inode floor (default 1,000,000).
  -j N                          Parallel build job count.
  -h, --help                    Show this help.

This script never flashes, reboots, runs adb/fastboot, signs images, or changes
device state. --build is explicit because it writes Android build output.
EOF
}

while (($#)); do
  case "$1" in
    --android-root)
      android_root="$(cd "${2:?missing directory}" && pwd)"
      shift 2
      ;;
    --plan)
      run_build=0
      shift
      ;;
    --build)
      run_build=1
      shift
      ;;
    --allow-existing-kernel-out)
      allow_existing_kernel_out=1
      shift
      ;;
    --artifact-dir)
      artifact_dir="${2:?missing artifact directory}"
      shift 2
      ;;
    --min-free-bytes)
      min_free_bytes="${2:?missing byte floor}"
      shift 2
      ;;
    --min-free-inodes)
      min_free_inodes="${2:?missing inode floor}"
      shift 2
      ;;
    -j)
      jobs="${2:?missing job count}"
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

if [[ -n "${jobs}" ]] && ! [[ "${jobs}" =~ ^[1-9][0-9]*$ ]]; then
  echo "error: -j requires a positive integer" >&2
  exit 2
fi
for value in "${min_free_bytes}" "${min_free_inodes}"; do
  if ! [[ "${value}" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: free-space/inode floors must be positive integers" >&2
    exit 2
  fi
done

kernel_out="${android_root}/out/target/product/kirby/obj/KERNEL_OBJ"

if (( ! run_build )); then
  cat <<EOF
reproduce_kernel_image=plan
android_root=${android_root}
lunch_target=${LUNCH_TARGET}
gki_commit=${GKI_COMMIT}
gki_tree=${GKI_TREE}
config_fragment=${CONFIG_FRAGMENT_PATH}
compiler=${CLANG_DIR}
build_command=m${jobs:+ -j${jobs}} kernel
expected_config_sha256=${REFERENCE_CONFIG_SHA256}
expected_image_sha256=${REFERENCE_IMAGE_SHA256}
kbuild_build_user=${KBUILD_BUILD_USER}
kbuild_build_host=${KBUILD_BUILD_HOST}
kbuild_build_timestamp=${KBUILD_BUILD_TIMESTAMP}
kbuild_build_version=${KBUILD_BUILD_VERSION}
minimum_free_bytes=${min_free_bytes}
minimum_free_inodes=${min_free_inodes}
artifact_dir=${artifact_dir:-required_for_build}
device_operation=none
EOF
  exit 0
fi

if [[ -z "${artifact_dir}" ]]; then
  echo "error: --artifact-dir is required with --build" >&2
  exit 2
fi
if [[ -d "${artifact_dir}" && -n "$(find "${artifact_dir}" -mindepth 1 -print -quit)" ]]; then
  echo "error: artifact directory is not empty: ${artifact_dir}" >&2
  exit 1
fi
mkdir -p "${artifact_dir}"
artifact_dir="$(cd "${artifact_dir}" && pwd)"

free_bytes="$(df --output=avail -B1 "${android_root}" | tail -n 1 | tr -d ' ')"
free_inodes="$(df --output=iavail "${android_root}" | tail -n 1 | tr -d ' ')"
{
  printf 'start=%s\n' "$(date -Is)"
  printf 'android_root=%s\n' "${android_root}"
  printf 'artifact_dir=%s\n' "${artifact_dir}"
  printf 'lunch_target=%s\n' "${LUNCH_TARGET}"
  printf 'gki_commit=%s\n' "${GKI_COMMIT}"
  printf 'gki_tree=%s\n' "${GKI_TREE}"
  printf 'device_commit=%s\n' "${DEVICE_COHERENT_COMMIT}"
  printf 'vendor_commit=%s\n' "${VENDOR_COMMIT}"
  printf 'free_bytes=%s\n' "${free_bytes}"
  printf 'minimum_free_bytes=%s\n' "${min_free_bytes}"
  printf 'free_inodes=%s\n' "${free_inodes}"
  printf 'minimum_free_inodes=%s\n' "${min_free_inodes}"
  printf 'allow_existing_kernel_out=%s\n' "${allow_existing_kernel_out}"
  printf 'ccache_enabled=1\n'
  printf 'ccache_exec=/usr/bin/ccache\n'
} > "${artifact_dir}/preflight.env"

if (( free_bytes < min_free_bytes || free_inodes < min_free_inodes )); then
  printf 'error: headroom below floor: bytes=%s/%s inodes=%s/%s\n' \
    "${free_bytes}" "${min_free_bytes}" "${free_inodes}" "${min_free_inodes}" >&2
  exit 1
fi

"${script_dir}/verify-kernel-inputs.sh" --android-root "${android_root}" \
  | tee "${artifact_dir}/verify-inputs-before.txt"

patch_helper="${android_root}/device/lenovo/kirby/tools/tb321fu_source_patch_stack.sh"
"${patch_helper}" status > "${artifact_dir}/source-patch-status.txt"
"${patch_helper}" check > "${artifact_dir}/source-patch-check.txt"
"${patch_helper}" reverse-check > "${artifact_dir}/source-patch-reverse-check.txt"

(
  cd "${android_root}"
  repo manifest -r
) > "${artifact_dir}/source-manifest.xml"
sha256sum "${artifact_dir}/source-manifest.xml" \
  > "${artifact_dir}/source-manifest.xml.sha256"

if [[ -d "${kernel_out}" && -n "$(find "${kernel_out}" -mindepth 1 -print -quit)" &&
      "${allow_existing_kernel_out}" -ne 1 ]]; then
  echo "error: refusing to reuse existing kernel output: ${kernel_out}" >&2
  echo "use a fresh checkout/output, or explicitly pass --allow-existing-kernel-out" >&2
  exit 1
fi

if [[ ! -x /usr/bin/ccache ]]; then
  echo "error: /usr/bin/ccache is required by the recorded build contract" >&2
  exit 1
fi

build_command=(m kernel)
if [[ -n "${jobs}" ]]; then
  build_command=(m "-j${jobs}" kernel)
fi

(
  cd "${android_root}"
  set +u
  source build/envsetup.sh >/dev/null
  lunch "${LUNCH_TARGET}"
  set -u
  export USE_CCACHE=1
  export CCACHE_EXEC=/usr/bin/ccache
  unset CCACHE_DISABLE
  export KBUILD_BUILD_USER
  export KBUILD_BUILD_HOST
  export KBUILD_BUILD_TIMESTAMP
  export KBUILD_BUILD_VERSION
  "${build_command[@]}"
) 2>&1 | tee "${artifact_dir}/build-kernel.log"

"${script_dir}/verify-kernel-inputs.sh" \
  --android-root "${android_root}" \
  --with-current-outputs \
  | tee "${artifact_dir}/verify-outputs-after.txt"
sha256sum \
  "${android_root}/${GENERATED_CONFIG_PATH}" \
  "${android_root}/${GENERATED_IMAGE_PATH}" \
  > "${artifact_dir}/kernel-outputs.sha256"
printf 'reproduce_kernel_image=pass image=%s sha256=%s\n' \
  "${android_root}/${GENERATED_IMAGE_PATH}" "${REFERENCE_IMAGE_SHA256}"
