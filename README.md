# NimbusLiveRampKit

A Nimbus SDK extension for **LiveRamp**. It provides a `LiveRamp` object that can initialize LiveRamp, fetch the envelope, and apply it to all Nimbus requests.

## Versioning

NimbusLiveRampKit **major versions are kept in sync** with the LiveRamp SDK. For example, NimbusLiveRampKit `2.x.x` depends on LiveRamp SDK `2.x.x`.
 
Minor and patch versions are independent — a NimbusLiveRampKit patch release does not necessarily correspond to a LiveRamp SDK patch release, and vice versa.
 
| NimbusLiveRampKit | LiveRamp SDK |
|---|---|
| 2.x.x | 2.x.x |

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
