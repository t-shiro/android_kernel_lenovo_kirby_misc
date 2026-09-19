# Initial publication checklist

The repository is prepared without committing or pushing. The repository owner
performs the external publication steps.

1. Review the staged diff and choose a top-level license for the newly written
   scripts and documentation. Existing imported files retain their own terms.
2. Create the initial commit on `main` and record its commit ID.
3. Replace `revision="main"` for the misc project in any production local
   manifest with that immutable commit ID. The checked-in example intentionally
   remains usable before the first commit exists.
4. Push `main` to
   `https://github.com/t-shiro/android_kernel_lenovo_kirby_misc`.
5. Create a release corresponding to the coherent TB321FU source snapshot.
6. Upload `android14-6.1-2024-11_r1.tar.gz` and `m9.731-Image` as Release
   assets; do not add them to ordinary Git history.
7. Verify their downloaded bytes against
   `manifests/m9.731-release-assets.sha256`.
8. Preserve a second copy of both assets outside GitHub.

Do not publish signing keys, signing configuration, account/device data,
ccache, Android `out`, or unrelated evidence artifacts.
