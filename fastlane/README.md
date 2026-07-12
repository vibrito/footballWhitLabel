fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

Run the BR2026Tests unit test suite

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate App Store screenshots for all supported locales

### ios release_notes

```sh
[bundle exec] fastlane ios release_notes
```

Push release notes (What's New) to App Store Connect

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload a TestFlight beta

### ios prepare_release

```sh
[bundle exec] fastlane ios prepare_release
```

Build a fresh binary, attach it to the App Store version, and push metadata + screenshots — does NOT submit for review

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```

Submit the currently-attached build for Apple review — does NOT auto-release; requires a manual Release click in App Store Connect after approval

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
