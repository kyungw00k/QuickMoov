fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac screenshots

```sh
[bundle exec] fastlane mac screenshots
```

Capture localized screenshots for App Store

### mac frame

```sh
[bundle exec] fastlane mac frame
```

Add device frames to screenshots

### mac screenshots_framed

```sh
[bundle exec] fastlane mac screenshots_framed
```

Capture and frame screenshots

### mac metadata

```sh
[bundle exec] fastlane mac metadata
```

Upload metadata to App Store Connect

### mac upload_screenshots

```sh
[bundle exec] fastlane mac upload_screenshots
```

Upload screenshots to App Store Connect

### mac upload_all

```sh
[bundle exec] fastlane mac upload_all
```

Upload everything (metadata + screenshots)

### mac release

```sh
[bundle exec] fastlane mac release
```

Full workflow: capture, frame, and upload

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
