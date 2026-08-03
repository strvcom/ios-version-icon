This PR adds an opt-in generated asset catalog mode so VersionIcon can create configuration-specific app icons without modifying tracked source assets. Existing projects retain the historical behavior unless they pass the new option.

## Changes
- Add `--outputAssetCatalog` for generating app icon sets outside the source asset catalog.
- Initialize and synchronize generated `.xcassets` and `.appiconset` metadata from `AppIconOriginal`.
- Document configuration-specific output names and Xcode build-phase setup.
- Add regression coverage proving multiple generated configurations leave source icons untouched.
- Update the distributed `Bin/VersionIcon` binary.

## Screenshot
TODO
