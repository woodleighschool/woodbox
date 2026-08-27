# WoodBox

[![Release](https://img.shields.io/github/v/release/woodleighschool/WoodBox?display_name=tag&sort=semver)](https://github.com/woodleighschool/WoodBox/releases/latest)
[![CI](https://github.com/woodleighschool/WoodBox/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/woodleighschool/WoodBox/actions/workflows/ci.yaml)
![macOS and iOS 26+](https://img.shields.io/badge/macOS%20%7C%20iOS-26%2B-000000?logo=apple&logoColor=white)
[![License](https://img.shields.io/github/license/woodleighschool/WoodBox)](https://github.com/woodleighschool/WoodBox/blob/main/LICENSE)

Native iOS and macOS tool for repair intake, return check-in, sale preparation, bulk scanning, and device administration.

## 🚀 Usage

The macOS app is attached to the [latest release](https://github.com/woodleighschool/woodbox/releases/latest) as a ZIP. Extract it, open WoodBox, then choose a workflow from the sidebar and scan or search for a device. Service connections and workflow defaults live in Settings.

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

## 📄 License

Licensed under the [GNU General Public License v3.0](LICENSE).
