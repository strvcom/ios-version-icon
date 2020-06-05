# VersionIcon

[![Version](https://img.shields.io/cocoapods/v/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)
[![License](https://img.shields.io/cocoapods/l/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)
[![Platform](https://img.shields.io/cocoapods/p/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)

<p align="center">
    <img src="https://i.ibb.co/4Zgprnc/AppIcon.png" width="180" max-width="180" alt="Marathon" />
</p>

A simple tool that can add an icon overlay with app version to your iOS app icon. Overlays can include the ribbon with app version (_Dev_, _Staging_, _Production_, _MVP_...) and/or version number. The icon overlays can be customized many ways. You can also use your own graphic resources. The VersionIcon tool is distributed in binary form, so it is independent on your project setup.

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## Requirements

- Xcode 10.0+

## Installation

### Cocoapods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate VersionIcon into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
pod 'VersionIcon', '~> 1.0.3'
```

Then, run the following command:

```bash
$ pod install
```

## Usage

* Make a duplicate of your app icon resource in asset catalog - let's have for example _AppIcon_ and _AppIconOriginal_. The copy is used as a backup. Production builds typically have no icon overlays. 
* Create a new Run Script Phase in Build Settings > Build Phases in your app
* Use this shell script:
```shell
if [ "${CONFIGURATION}" = "Release" ]; then
    "Pods/VersionIcon/Bin/VersionIcon" --resources "Pods/VersionIcon/Bin" --original
else
    "Pods/VersionIcon/Bin/VersionIcon"  --ribbon Blue-TopRight.png --title Devel-TopRight.png --resources "Pods/VersionIcon/Bin" --strokeWidth 0.07
fi
```
* If your projects contains different configuration names, you'll need to adjust the script.
* Move this script phase above the Copy Bundle Resources phase.
* If you need to use your own ribbon or title asset, you can specify full path to image file

## Parameters
* Full description of parameters is available when you run VersionIcon with `--help` parameter
```
VersionIcon prepares iOS icon with ribbon, text and version info overlay

Usage: versionIcon <params>
  --appIcon <The name of app icon asset>:
      The asset that is modified by script. Default = 'AppIcon'.
  --appIconOriginal <The name of original app icon asset>:
      This asset is used as backup of original icon. Default = 'AppIconOriginal'.
  --ribbon <Icon ribbon color>:
      Name of PNG file in Ribbons folder or absolute path to Ribbon image
  --title <Icon ribbon title>:
      Name of PNG file in Titles folder or absolute path to Title image
  --fillColor <Title fill color>:
      The fill color of version title in #xxxxxx hexa format. Default = '#FFFFFF'.
  --strokeColor <Title stroke color>:
      The stroke color of version title in #xxxxxx hexa format. Default = '#000000'.
  --strokeWidth <Version Title Stroke Width>:
      Version title stroke width related to icon width. Default = '0.03'.
  --font <Version label font>:
      Font used for version title. Default = 'Impact'.
  --titleSize <Version Title Size Ratio>:
      Version title size related to icon width. Default = '0.2'.
  --horizontalTitlePosition <Version Title Size Ratio>:
      Version title position related to icon width. Default = '0.5'.
  --verticalTitlePosition <Version Title Size Ratio>:
      Version title position related to icon width. Default = '0.2'.
  --titleAlignment <Version Title Text Alignment>:
      Possible values are left, center, right. Default = 'center'.
  --versionStyle <The format of version label>:
      Possible values are dash, parenthesis, versionOnly, buildOnly. Default = 'dash'.
  --resources <VersionIcon resources path>:
      Default path where Ribbons and Titles folders are located. It is not necessary to set when script is executed as a build phase in Xcode
  --original:
      Use original icon with no modifications (for production)
  --help:
      Shows this info summary
```

## Contributing

Issues and pull requests are welcome!

## Author

* Daniel Čech [GitHub](https://github.com/DanielCech) 

## License

VersionIcon is released under the MIT license. See [LICENSE](https://github.com/DanielCech/DeallocTests/blob/master/LICENSE) for details.

