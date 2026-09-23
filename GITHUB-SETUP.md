# Restoring the private GitHub checkout

The macOS app source lives in the private `shawonibnkamal/doclin-macos` repository.
Generated application bundles and build output are excluded from Git.

The large, pinned voice dependencies are preserved in the private
`voice-dependencies-v1` release. Restore them from the repository root before
running `scripts/build.sh`:

```sh
mkdir -p .build/voice-download
gh release download voice-dependencies-v1 --repo shawonibnkamal/doclin-macos \
  --pattern 'voice-dependencies.tar.gz*' --dir .build/voice-download
(cd .build/voice-download && shasum -a 256 -c voice-dependencies.tar.gz.sha256)
tar -xzf .build/voice-download/voice-dependencies.tar.gz -C .
scripts/build.sh
```

The archive contains `vendor/voice`, including the original model, universal
libraries, upstream source archives, headers, licenses, and checksum manifest.
Access to the private repository is required to download it.
