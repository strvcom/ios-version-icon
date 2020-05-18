# VersionIcon

[![Version](https://img.shields.io/cocoapods/v/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)
[![License](https://img.shields.io/cocoapods/l/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)
[![Platform](https://img.shields.io/cocoapods/p/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)

<p align="center">
    <img src="https://i.ibb.co/4Zgprnc/AppIcon.png" width="180" max-width="180" alt="Marathon" />
</p>

A simple tool that prepares app icon overlays. Overlays can include the ribbon with app version (Dev, Staging, Production, MVP...) and/or version number. The VersionIcon tool is distributed in binary form, so it is independent on your project setup.

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## Requirements

- iOS 8.0+ / Mac OS X 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 10.0+

## Installation

### Dependency Managers
<details>
  <summary><strong>CocoaPods</strong></summary>

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate DeallocTests into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'VersionIcon', :git=>'https://github.com/DanielCech/VersionIcon.git', :tag => 'v1.0.0'
```

Then, run the following command:

```bash
$ pod install
```

</details>

## Usage

* Create a new Run Script Phase in Build Settings > Build Phases in your app
* Use this shell script:
```shell
if [ "${CONFIGURATION}" = "Release" ]; then
    "Pods/VersionIcon/Bin/VersionIcon" --resources "Pods/VersionIcon/Bin" --original
else
    "Pods/VersionIcon/Bin/VersionIcon" --ribbon Blue.png --title Devel.png --resources "Pods/VersionIcon/Bin" --strokeWidth 0.07
fi
```
* If your projects contains different configuration names, you'll need to adjust the script.
* Move this script phase above the Copy Bundle Resources phase.

## Contributing

Issues and pull requests are welcome!

## Author

* Daniel Čech [GitHub](https://github.com/DanielCech) 

## License

VersionIcon is released under the MIT license. See [LICENSE](https://github.com/DanielCech/DeallocTests/blob/master/LICENSE) for details.

