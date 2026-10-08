# Changelog

## [2.5.0](https://github.com/woodleighschool/woodbox/compare/v2.4.0...v2.5.0) (2026-10-08)


### Features

* overhaul device workflows ([#8](https://github.com/woodleighschool/woodbox/issues/8)) ([0ac4803](https://github.com/woodleighschool/woodbox/commit/0ac48034336149e9d0a1c70bb3a8b63d9bf2c29e))
* **scan:** report scan results in the scanner header ([f996677](https://github.com/woodleighschool/woodbox/commit/f996677c0930d28db5f6df7bec78723aa35415c8))
* **search:** put the scan button beside the search field ([db9b11b](https://github.com/woodleighschool/woodbox/commit/db9b11b1bc211ac44ad5334b673338f94d84ed81))
* share CSV export across restock and sale ([33aad9f](https://github.com/woodleighschool/woodbox/commit/33aad9f673a3c23ad08c3ed2c9f36d965ac32727))


### Bug Fixes

* **cache:** report a failed pull to refresh ([f45d376](https://github.com/woodleighschool/woodbox/commit/f45d3760a790ae95562d2e09d5ec9b682e1f9be7))
* **cache:** wait for an in-flight refresh to finish ([07b2d6a](https://github.com/woodleighschool/woodbox/commit/07b2d6a9f115d9cbff388cc1141c27b0cec8049b))
* **dedupe:** keep the latest-record marker at the leading edge ([768561b](https://github.com/woodleighschool/woodbox/commit/768561bda71eb636b474746f41c891d242de3ff8))
* **devices:** set identifier symbols inline with their values ([ea5f623](https://github.com/woodleighschool/woodbox/commit/ea5f623230864bc82da5949ac2d589fa7cc3fdf5))
* **jamf:** confirm uncertain deletions by reading back ([f102021](https://github.com/woodleighschool/woodbox/commit/f102021f2928024803f9e5deb16db9d01b515028))
* keep device queues reusable ([b3cf3b3](https://github.com/woodleighschool/woodbox/commit/b3cf3b3169266595fd686ff1a74213acce6e2a97))
* **mdm:** match records by identity when removing them ([e78a48a](https://github.com/woodleighschool/woodbox/commit/e78a48a1995c71a94f687f4e81030c6dee8349e9))
* **queue:** keep listed devices in step with the cache ([32bde8e](https://github.com/woodleighschool/woodbox/commit/32bde8e97cba3f0b075e2ad5578265a24832053d))
* **queue:** let Restock and Sale list the same device ([0d2972d](https://github.com/woodleighschool/woodbox/commit/0d2972d88b15b70bc228ffb8f39197e91997d9c9))
* **repair:** reset the form once a repair is submitted ([024b0a9](https://github.com/woodleighschool/woodbox/commit/024b0a9913c59b8b16a179375507fe79539b8e58))
* **sale:** show the grade as the row's value ([7b719e5](https://github.com/woodleighschool/woodbox/commit/7b719e54e758fdc18245aa2704a3c64ba18b4156))
* **scan:** ignore printed words that match no device ([72ef70d](https://github.com/woodleighschool/woodbox/commit/72ef70dbcf19047792cb6e1bf8681328499a49c5))
* **search:** line up device suggestions ([b1b6d85](https://github.com/woodleighschool/woodbox/commit/b1b6d850a692d3ce2369c411cd8887aa601d616b))
* **settings:** dismiss the sheet by swiping down ([6a4b49f](https://github.com/woodleighschool/woodbox/commit/6a4b49fc4ea193fd0889b4750b856dd9cdcc49a8))
* **settings:** require an integration's settings before enabling it ([0c33e2f](https://github.com/woodleighschool/woodbox/commit/0c33e2f5b21bd445f74ebf9be92902cb4c89a692))
* **settings:** use plain text fields ([bd0ab96](https://github.com/woodleighschool/woodbox/commit/bd0ab964ced9b40f7ba556f27bdd92e45d7976d5))

## [2.4.0](https://github.com/woodleighschool/woodbox/compare/v2.3.1...v2.4.0) (2026-08-25)


### Features

* remove vendor logos and unify refresh ([f345ef5](https://github.com/woodleighschool/woodbox/commit/f345ef5a196281b3ec0839cf5ae66c0811555c75))
* set app accent color ([9a3acaf](https://github.com/woodleighschool/woodbox/commit/9a3acafc30f2d7c3148df78fba8cad45c0f7ac74))


### Bug Fixes

* adopt the data protection Keychain ([c743a6f](https://github.com/woodleighschool/woodbox/commit/c743a6f7d8c8d6718fdcc41d9847eca99f7505bf))
* **app:** declare exempt encryption ([85f8350](https://github.com/woodleighschool/woodbox/commit/85f8350453910e3f2767c271c8cb97ad5018977a))
* **ci:** pin released notarization action ([acf8c24](https://github.com/woodleighschool/woodbox/commit/acf8c244aab9579c963d3661a906d8c3e199734b))
* **xcode:** xcode 26.3 min compatability ([234e700](https://github.com/woodleighschool/woodbox/commit/234e700808fef865c47b244ee84294665ca80466))


### Continuous Integration

* use apple notarize v2 ([e369540](https://github.com/woodleighschool/woodbox/commit/e36954070312bcd825e58991777589762a17c7df))
* use shared App Store Connect key ([1673cae](https://github.com/woodleighschool/woodbox/commit/1673cae305f332c11224286fdab8ddcbc5aa9f13))
* use shared notarization action ([c334649](https://github.com/woodleighschool/woodbox/commit/c334649dfbda0f5af87bb24c1ee01c3304c3b46d))


### Miscellaneous Chores

* align ignore rules ([dae8eef](https://github.com/woodleighschool/woodbox/commit/dae8eefecbda8f9ce3450716be85c29577680c17))
* normalise icon ([2aa896f](https://github.com/woodleighschool/woodbox/commit/2aa896f4ca2b7e33e5c6af3234aea343dc82f76b))
* post bootstrap cleanup ([0eaec59](https://github.com/woodleighschool/woodbox/commit/0eaec599a98c282c3fdc538ee8f1ec703ec56909))
* **release-please:** sync configuration ([ec5dd3c](https://github.com/woodleighschool/woodbox/commit/ec5dd3cbabc88cc642630b71c5f35fe2d53bd9b9))

## [2.3.1](https://github.com/woodleighschool/woodbox/compare/2.3.0...v2.3.1) (2026-08-22)


### Bug Fixes

* **app:** explicit min deployment ([5f3cda9](https://github.com/woodleighschool/woodbox/commit/5f3cda9992aaa3725b9edd83451ab002406c4db3))


### Documentation

* add repository overview ([0484ce4](https://github.com/woodleighschool/woodbox/commit/0484ce43b8ab927370d42c4033930ba43c8f73de))
* clarify repository guidance ([13d3f58](https://github.com/woodleighschool/woodbox/commit/13d3f58dfe407e4e4e846f69ed16d8a7727f722c))


### Code Refactoring

* **swift:** scope platform-only helpers ([66cccdc](https://github.com/woodleighschool/woodbox/commit/66cccdc8a5b3369042c4110f1e7a7c4143fc1561))

## Changelog
