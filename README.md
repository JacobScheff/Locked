# Locked

Study first. Unlock later.

Locked is an iOS app that connects coursework to access to distracting apps. Finish assignments to earn Karma and Keys, track upcoming work, and use Apple's Screen Time APIs to manage selected apps.

## Features

- Courses and assignments with due dates and completion rewards.
- Gradescope and Brightspace imports through sign-in on the provider's website.
- Screen Time app selection, usage reports, and system shields.
- Keys to unlock apps, an emergency override, and a home-screen widget.

## Build requirements

- A Mac with **Xcode 26.3 or newer** and the iOS SDK. The project targets **iOS 26.2 or newer**.
- An Apple Developer team with the required capabilities for running on a physical device.
- A physical iPhone or iPad for validating Screen Time authorization, usage reports, and shields.

There are no third-party package dependencies or backend services to configure. School accounts are only needed to exercise their respective imports. The integration code depends on provider websites and may need updates when those sites change.

## Get started

```sh
git clone https://github.com/JacobScheff/Locked.git
cd Locked
open Locked.xcodeproj
```

Select the **Locked** scheme. For an unsigned compilation check without an Apple account:

```sh
bash scripts/build.sh
# Optional: check the Release configuration too.
bash scripts/build.sh Release
```

These commands compile the app and embedded extensions for a generic iOS device with signing disabled. The output cannot be installed on a device. Simulator builds do not replace physical-device Screen Time testing.

### Run your own signed build

The checked-in signing team and identifiers belong to the upstream project. They are identifiers, not credentials. For your fork:

1. In **Signing & Capabilities**, select your own team for all six targets: `Locked`, `Locked-WidgetExtension`, `DeviceActivityMonitor`, `DeviceActivityReport`, `ShieldConfiguration`, and `ShieldAction`.
2. Give the app a unique bundle identifier and update every extension identifier to use that app identifier as its prefix. Update both Debug and Release build settings.
3. Register your own App Group and replace `group.com.Jacob-Scheff.Locked` in all six entitlement files, `Shared/ScreenTimeSupport.swift`, `Locked-Widget/Locked_Widget.swift`, and `ModelContainer+Ext.swift`.
4. Update the upstream app identifiers and prefix check in `ExcludedApps` in `Shared/ScreenTimeSupport.swift` so your build excludes itself from tracking and shielding. Also use your own identifier for the Keychain service in `Locked/ExternalSources.swift` and the URL type name in `Locked/Info.plist`. If running alongside upstream, choose a unique URL scheme and update its references too.
5. Enable App Groups for all targets and Family Controls for the app and four Screen Time extensions. The project also declares `com.apple.developer.family-controls.app-and-website-usage`; make sure your profiles support every declared entitlement. Do not remove capabilities merely to silence signing errors if you need their features.
6. Let Xcode generate matching provisioning profiles, select your device, and run. In the app, allow Screen Time and choose apps to manage. School imports can be connected separately under Sources.

Apple controls entitlement availability. Distribution through TestFlight or the App Store requires Apple's Family Controls distribution approval for the app and each applicable extension. See Apple's [configuration guide](https://developer.apple.com/documentation/xcode/configuring-family-controls) and [entitlement request guide](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement). Keep signing credentials and personal provisioning files out of pull requests.

## Source layout

- `Locked/`: SwiftUI app, coursework models, school integrations, and Screen Time manager.
- `Logic.swift`: shared rewards and locking logic.
- `Shared/ScreenTimeSupport.swift`: shared storage and Screen Time helpers.
- `Locked-Widget/`: WidgetKit extension.
- `DeviceActivityMonitor/` and `DeviceActivityReport/`: activity monitoring and usage reporting.
- `ShieldConfiguration/` and `ShieldAction/`: shield appearance and actions.
- `Locked.xcodeproj/`: Xcode project and shared schemes.

## Contributing and support

Read [CONTRIBUTING.md](CONTRIBUTING.md) for development and validation steps, and the [Code of Conduct](CODE_OF_CONDUCT.md) before participating. Use [GitHub Issues](https://github.com/JacobScheff/Locked/issues) for bugs and feature requests. Redact student information, account details, and session cookies from reports.

Report vulnerabilities using the process in [SECURITY.md](SECURITY.md). Maintainers can finish the repository configuration using the [GitHub setup checklist](docs/github-setup.md).

## License

Licensed under the [MIT License](LICENSE), copyright 2026 Jacob Scheff. Gradescope, Brightspace, and Apple product names belong to their respective owners; this project is not affiliated with or endorsed by those providers.
