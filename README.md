[![Version](https://img.shields.io/cocoapods/v/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)
[![License](https://img.shields.io/cocoapods/l/VersionIcon.svg?style=flat)](https://cocoapods.org/pods/VersionIcon)

<p align="center">
    <img src="https://i.ibb.co/pBJbxxsH/App-Icon60x60-2x.png" width="180" max-width="180" alt="VersionIcon" />
</p>

# VersionIcon

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
pod 'VersionIcon', '~> 1.0.8'
```

Then, run the following command:

```bash
$ pod install
```

## Usage

* Make a duplicate of your app icon resource in asset catalog - let's have for example _AppIcon_ and _AppIconOriginal_. The copy is used as a backup. Production builds typically have no icon overlays. (if your project contains icon resource with other than this default name, you need to specify it using `--appIcon` and/or `--appIconOriginal` parameter.
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
#### Ribbon Style
* `--ribbon <Icon ribbon>`
    * Icon ribbon. The folder Ribbons contains variety of ribbons .png files with different colors and positions. You can also specify the absolute path to your custom .png.
    
* `--title <Icon ribbon title>`
    * The title on ribbon. You can choose from a several predefined titles in different positions in Titles folder. Or you can provide absolute path to your custom ribbon title image. (Ribbon titles are images with transparency, custom text is not supported yet)

#### Icon version Title
* `--fillColor <Title fill color>`
    * The fill color of version title in `#xxxxxx` hexa format. Default fill color is white ('#FFFFFF').
    
* `--strokeColor <Title stroke color>`
    * The stroke color of version title in `#xxxxxx` hexa format. Default stroke color is black ('#000000').
    
* `--strokeWidth <Version Title Stroke Width>`
    * The title stroke width related to icon width. Default value of stroke width is '0.03'.
    
* `--font <Version label font>`
    * Font used for version title. Default font is 'Impact'.
    
* `--titleSize <Version Title Size Ratio>`
    * Version title size related to icon width. Default title size is '0.2'.
    
* `--horizontalTitlePosition <Version Title Size Ratio>`
    * Version title position related to icon width. Default = '0.5'.
    
* `--verticalTitlePosition <Version Title Size Ratio>`
    * Version title position related to icon width. Default = '0.2'.
      
* `--titleAlignment <Version Title Text Alignment>`
    * Possible values are left, center, right. Default = 'center'.
    
* `--versionStyle <The format of version label>`
    * Possible values are _dash_, _parenthesis_, _versionOnly_, _buildOnly_. Default = 'dash'.

#### Script Setup
* `--resources <VersionIcon resources path>`
    * Default path where Ribbons and Titles folders are located. It is not necessary to set when script is executed as a build phase in Xcode
    
* `--original`
    * If you need to use just original icon without any modifications, use this parameter. The production app typically has no icon overlay.
    
* `--help`
    * Full description of parameters is available when you run VersionIcon with `--help` parameter

## Debugging

If you want to modify the behavior and debug VersionIcon in context of your project, you need a special setup of the scheme. The screenshot shows the commandline arguments passed on launch. These parameters can be copied from the existing VersionIcon call build phase. And three environment variables that are necessary to propagate. The values of these environment are visible in the Xcode's Report navigator. All checkboxes should be on.

<p align="center">
    <img src="https://i.ibb.co/5XC6fT9p/Scheme-Setup.png" width="936" max-width="534" alt="Scheme" />
</p>


## Contributing

Issues and pull requests are welcome!

## Author

* Daniel Čech [GitHub](https://github.com/DanielCech) 

## License

VersionIcon is released under the MIT license. See [LICENSE](https://github.com/DanielCech/DeallocTests/blob/master/LICENSE) for details.

