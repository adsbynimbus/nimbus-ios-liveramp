# NimbusLiveRampKit
 
A Nimbus SDK extension for **LiveRamp**. It provides a `LiveRamp` object that can initialize LiveRamp, fetch the envelope, and apply it to all Nimbus requests.
 
## Versioning
 
Starting with version `3.0`, NimbusLiveRampKit talks to the [ATS API](https://developers.liveramp.com/authenticatedtraffic-api/docs/ats-api-implementation-guide-for-mobile-publishers) directly and has no third-party dependencies. The LiveRamp SDK (LRAts) it previously wrapped is [scheduled to sunset in September 2026](https://developers.liveramp.com/authenticatedtraffic-api/changelog/ats-mobile-sdk-users-to-transition-to-ats-api).
 
Versions follow [semantic versioning](https://semver.org) and are no longer tied to the LiveRamp SDK, so you can use the latest release.
 
### Upgrading from 2.x
 
NimbusLiveRampKit `2.x.x` depends on LiveRamp SDK `2.x.x` — major versions were kept in sync, while minor and patch versions were independent.
 
| NimbusLiveRampKit | LiveRamp SDK |
|---|---|
| 3.x.x | none |
| 2.x.x | 2.x.x |
 
If you are still on `2.x`, upgrade before the LRAts sunset in September 2026.

## Installation

### Swift Package Manager

#### Xcode Project

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the repository URL:
   ```
   https://github.com/adsbynimbus/nimbus-ios-liveramp
   ```
3. Set the dependency rule to **Up to Next Major Version** and enter `2.0.0` as the minimum.
4. Click **Add Package** and select the **NimbusLiveRampKit** library when prompted.

#### Package.swift

If you're managing dependencies through a `Package.swift` file, add the following:

```swift
dependencies: [
    .package(url: "https://github.com/adsbynimbus/nimbus-ios-liveramp", from: "2.0.0")
]
```

Then add the product to your target:

```swift
.product(name: "NimbusLiveRampKit", package: "nimbus-ios-liveramp")
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'NimbusLiveRampKit'
```

Then run:

```sh
pod install
```

## Usage
 
Fetch the LiveRamp envelope:
 
```swift
let liveRamp = LiveRamp(
    configId: "<liverampConfigId>",
    email: "info@mycompany.com",
    hasConsentForNoLegislation: true
)

// test using .fetchEnvelope(isTestMode: true)
try await liveRamp.fetchEnvelope().applyToNimbus()
```

That's it — LiveRamp is now enabled in all upcoming requests.

## Documentation

- [Nimbus iOS SDK Documentation](https://docs.adsbynimbus.com/docs/sdk/ios) — integration guides, configuration, and API reference.
- [DocC API Reference](https://iosdocs.adsbynimbus.com) — auto-generated documentation for the latest release.
