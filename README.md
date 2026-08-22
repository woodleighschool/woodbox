# WoodBox

Native iOS and macOS tool for repair intake, return check-in, sale preparation, bulk scanning, and device administration.

## 🚀 Usage

Choose a workflow from the sidebar, then scan or search for a device. Configure service connections and workflow defaults in Settings.

## 🧑‍💻 Development

Open `WoodBox.xcodeproj` in Xcode and use the shared `WoodBox` scheme, or install the locked command-line tools and use the repository tasks:

```bash
mise install
mise run fmt-check
mise run lint
mise run test
mise run build
mise run workflow-lint
```

`mise run build` builds the unsigned macOS app. iOS builds remain in Xcode and App Store Connect.

## 📦 Releases

Numeric releases publish a signed and notarized `WoodBox-<version>.zip` for macOS. We distribute iOS builds through App Store Connect as a private Custom App.

## 📄 License

Licensed under the [GNU General Public License v3.0](LICENSE).
