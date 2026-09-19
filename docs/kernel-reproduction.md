# TB321FU M9.731 kernel reproduction

## Scope

This procedure reconstructs and verifies the kernel inputs selected by the
M9.731-qualified TB321FU build. It is host-only. It does not reproduce signing,
construct a complete OTA, flash a partition, contact the tablet, or claim that
a newly built full ROM is runtime-qualified.

The product deliberately combines:

- the unmodified Android Common Kernel 6.1 source at a fixed AOSP release tag;
- the device-owned `CONFIG_RFKILL=y` fragment;
- a fixed clang toolchain revision;
- a retained QTI MSM UAPI header archive;
- Stock-derived DTB/DTBO and Stock-generation module/DLKM inputs owned by the
  device tree.

The current GKI build produces the core `Image` only. It does not rebuild the
Stock-generation vendor modules, DTB or DTBO.

## Frozen identity

The machine-readable authority is
`manifests/m9.731-kernel-inputs.env`. Important identifiers are:

```text
AOSP tag:    android14-6.1-2024-11_r1
tag object:  bd9fcec9549651a62ce0b3753f3b14c66aaf0cc1
commit:      d03cb1d7abcd078dabe73ed711be068ca9b364b8
tree:        a9b697b4ac12c1f8b3940dc330d1f55576814ea5
lunch:       lineage_kirby-bp4a-user
device:      9b2984dbec3a8486df283a0143deeabdb199620a
vendor:      cad070d14a40506ad135547f9f29f205bd9b65b5
```

The reference `Image` embeds the following Kbuild identity, so it is also
locked for byte-level comparison:

```text
KBUILD_BUILD_USER=romanov
KBUILD_BUILD_HOST=ichika
KBUILD_BUILD_TIMESTAMP=Thu Aug 27 05:09:17 JST 2026
KBUILD_BUILD_VERSION=1
```

The retained M9.731 repo manifest records device commit `17c1369...` because
the one-line RKP hostname source change was uncommitted at build preflight.
Device commit `9b2984d...` is the later coherent commit containing that exact
runtime line plus its evidence. Use `9b2984d...` for reconstruction and retain
the manifest/diff evidence for historical attribution.

## Required checkout layout

```text
device/lenovo/kirby
vendor/lenovo/kirby
kernel/google/android14-6.1-2024-11_r1
kernel/lenovo/kirby-misc
kernel/prebuilts/msm_uapi_headers.tar.gz
prebuilts/clang/host/linux-x86/clang-r563880c
```

The full shared Lineage source must match
`manifests/m9.731-repo-manifest.xml`, with the 25-row source patch stack from
the device repository applied and passing its status/check/reverse-check gates.

## 1. Fetch the exact GKI source

Online, from the locked AOSP tag:

```bash
kernel/lenovo/kirby-misc/scripts/fetch-gki.sh
```

Offline, from the retained GitHub Release asset or independent backup:

```bash
kernel/lenovo/kirby-misc/scripts/fetch-gki.sh \
  --archive /path/to/android14-6.1-2024-11_r1.tar.gz
```

The helper refuses an existing destination. The Git path verifies tag object,
commit and tree. The archive path verifies size, archive SHA-256 and the
reconstructed Git tree without modifying the extracted worktree.

## 2. Install the retained UAPI input

The qualified source currently expects this historical path:

```text
kernel/prebuilts/msm_uapi_headers.tar.gz
```

Inspect the operation first, then install only if absent:

```bash
kernel/lenovo/kirby-misc/scripts/install-misc-inputs.sh
kernel/lenovo/kirby-misc/scripts/install-misc-inputs.sh --install
```

The helper never overwrites a differing existing file. A future reviewed
device-tree change may point `TARGET_PREBUILT_KERNEL_HEADERS` directly at the
misc repository, but M9.731 reconstruction keeps the historical path.

## 3. Verify every frozen input

```bash
kernel/lenovo/kirby-misc/scripts/verify-kernel-inputs.sh
```

This checks the GKI commit/tree and clean worktree, device/vendor revisions,
base defconfig, TB321FU fragment, retained generated config, UAPI archive,
DTB/DTBO, clang repo revision and full M9.731 repo manifest.

To compare an already generated output tree as well:

```bash
kernel/lenovo/kirby-misc/scripts/verify-kernel-inputs.sh \
  --with-current-outputs
```

## 4. Review the build plan

```bash
kernel/lenovo/kirby-misc/scripts/reproduce-kernel-image.sh --plan
```

The plan is read-only. It records the exact lunch target, build target and
expected hashes.

## 5. Build only with separate authority

A host build writes `out` and can consume substantial disk and time. Confirm
the project build authority, disk/inode floor, output retention location,
source manifest and ccache contract before running:

```bash
kernel/lenovo/kirby-misc/scripts/reproduce-kernel-image.sh \
  --build \
  --artifact-dir /path/to/retained/kernel-reproduction-evidence \
  -j8
```

The helper requires a fresh kernel output directory unless reuse is explicitly
selected. It defaults to a 40 GiB/1,000,000-inode conservative floor, freezes a
source manifest, runs the 25-row source-patch status/check/reverse-check gates,
and retains the preflight, build log and output hashes under the artifact
directory. After `m kernel`, it requires both of these hashes:

```text
.config  f81d45ff16bc4c837e34244078531530b68433bec9910f4ca320f43910b36e97
Image    7a6debb4a4bacb559b704e5be0a6d5a640a91eabb0229512d4925cdc7bdc586c
```

A matching `Image` proves the frozen kernel-output reproduction only. A full
ROM still requires exact target-files/AVB/signing inputs and all corresponding
host, device and human gates.

## GitHub Release assets

Publish the following without adding them to Git history:

```text
android14-6.1-2024-11_r1.tar.gz
m9.731-Image
```

Verify them with:

```bash
sha256sum -c manifests/m9.731-release-assets.sha256
```

The `.config`, UAPI archive, lock, source manifest and scripts are small and
remain ordinary Git-tracked files. Do not publish private signing material.

## Known provenance boundary

The exact UAPI archive is retained and hash-locked, but its original generator
revision and generation command are not known. This repository closes loss of
the selected bytes; it does not erase that provenance debt. Do not regenerate
or replace the archive without a separate comparison and build/runtime gate.
