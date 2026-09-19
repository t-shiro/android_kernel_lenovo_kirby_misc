# M9.731 publication and asset checklist

The repository owner performs all external commit, tag, push and GitHub Release
steps. Existing published tags are immutable; documentation corrections belong
in a new commit and, when a frozen replacement is needed, a new tag.

1. Review the staged diff. Existing imported files retain their own terms.
2. Commit the documentation and manifest update on `main` and record its commit
   ID. Do not move the existing `tb321fu-m9.731-runtime-qualified-v1` tag.
3. Keep production local manifests pinned to an immutable tag or commit. The
   checked-in example is pinned to the existing M9.731 v1 tag.
4. Push the new commit on `main` to
   `https://github.com/t-shiro/android_kernel_lenovo_kirby_misc`.
5. Upload `pvmfw.img` to the existing M9.731 Release alongside
   `android14-6.1-2024-11_r1.tar.gz` and `m9.731-Image`; do not add any of the
   three assets to ordinary Git history. Update the Release description to
   identify `pvmfw.img` as a full-ROM AVB dependency rather than a GKI build
   input, and link to the commit containing the three-entry checksum manifest.
6. Confirm the uploaded `pvmfw.img` reports size `1048576` and SHA-256
   `7febe8ccadacf3a8dd2dfa85f98385fdca35044046b592b119849dd8c9428dc5`.
7. Download all three assets into `release-assets/` and verify them against
   `manifests/m9.731-release-assets.sha256`.
8. Preserve a second copy of all three assets outside GitHub.

Do not publish signing keys, signing configuration, account/device data,
ccache, Android `out`, or unrelated evidence artifacts.
