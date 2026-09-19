# TB321FU kernel reproduction inputs

This repository owns the small, TB321FU-specific inputs and verification
records that do not belong in the unmodified Android Common Kernel source
tree or in `device/lenovo/kirby`.

The current frozen snapshot is M9.731. It uses the unmodified AOSP Android
Common Kernel tag `android14-6.1-2024-11_r1` plus the configuration fragment
owned by `android_device_lenovo_kirby`.

## Repository contents

- `prebuilts/msm_uapi_headers.tar.gz`: exact QTI userspace UAPI input used by
  the Lineage build. Its generation provenance remains open maintenance debt.
- `configs/m9.731.generated.config`: reference generated kernel configuration.
  It is a verification output, not the source configuration authority.
- `manifests/m9.731-kernel-inputs.env`: machine-readable source, toolchain,
  configuration, board-asset, and reference-output lock.
- `manifests/m9.731-repo-manifest.xml`: exact Lineage source manifest retained
  by the M9.731 build evidence.
- `scripts/`: fail-closed fetch, input installation, verification, and kernel
  reproduction helpers.
- `docs/kernel-reproduction.md`: end-to-end procedure and scope boundaries.

The source configuration authority remains:

```text
device/lenovo/kirby/kernel/source_gki_tb321fu.config
```

The board DTB, DTBO and selected vendor-ramdisk module payloads also remain in
`android_device_lenovo_kirby`. They are referenced and hash-locked here rather
than duplicated.

## Quick verification

Check out this repository at `kernel/lenovo/kirby-misc` in the Lineage source
tree, then run:

```bash
kernel/lenovo/kirby-misc/scripts/verify-kernel-inputs.sh
kernel/lenovo/kirby-misc/scripts/reproduce-kernel-image.sh --plan
```

Neither command builds an image or contacts a device. Building requires the
explicit `--build` option and a clean kernel output directory.

## Large release assets

The following retained files are intentionally not committed to Git:

```text
android14-6.1-2024-11_r1.tar.gz
m9.731-Image
```

Their exact sizes and hashes are recorded in
`manifests/m9.731-release-assets.sha256`. Publish them as GitHub Release assets
and retain at least one independent offline copy.

## Exclusions

This repository must not contain signing keys, ccache, the Android `out`
directory, account/device data, or the 1.5 GiB non-product
`kernel/lenovo/TB321FU` research workspace. The research workspace is not the
normal `TARGET_KERNEL_SOURCE` for the qualified build.

This repository also does not replace the full M9.731 build/runtime evidence.
Its purpose is to make the selected kernel inputs discoverable, fetchable and
mechanically verifiable.
