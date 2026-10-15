# WoodBox

[![Release](https://img.shields.io/github/v/release/woodleighschool/WoodBox?display_name=tag&sort=semver)](https://github.com/woodleighschool/WoodBox/releases/latest)
[![CI](https://github.com/woodleighschool/WoodBox/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/woodleighschool/WoodBox/actions/workflows/ci.yaml)
![macOS and iOS 26+](https://img.shields.io/badge/macOS%20%7C%20iOS-26%2B-000000?logo=apple&logoColor=white)
[![License](https://img.shields.io/github/license/woodleighschool/WoodBox)](https://github.com/woodleighschool/WoodBox/blob/main/LICENSE)

Native iOS and macOS tool for repair intake, device restocking, sale preparation, and device administration.

## 🚀 Usage

The macOS app is attached to the [latest release](https://github.com/woodleighschool/woodbox/releases/latest) as a ZIP, and the iOS app comes through TestFlight. Extract the ZIP, open WoodBox, then choose a workflow and scan or search for a device. Restock and Sale accept one device or a working queue, using the camera on iOS and typed or USB scanner input on macOS. Enrollment builds the same kind of queue, or takes every device on an Intune enrollment policy, shows each device's current policy, and assigns another. Service connections and workflow defaults live in Settings.

Snipe-IT assets are cached for search and device details. Dedupe loads current Jamf and Intune records when opened; Enrollment loads current Intune enrollment devices and policies. Both include devices without a matching asset and work without a Snipe-IT connection. Refresh updates the current tool. Restock and Sale verify the asset in Snipe-IT before removing current MDM records and applying the selected status.

## 🧑‍💻 Development

Open `WoodBox.xcodeproj` in Xcode and use the shared `WoodBox` scheme, or install the locked command-line tools and use the repository tasks:

```bash
mise install
mise run fmt-check
mise run lint
mise run test
mise run build
```

## 📄 License

Licensed under the [GNU General Public License v3.0](LICENSE).
