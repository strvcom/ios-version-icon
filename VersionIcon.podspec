Pod::Spec.new do |s|
  s.name                      = 'VersionIcon'
  s.module_name               = 'VersionIcon'
  s.version                   = '1.0.9'
  s.summary                   = 'Script written in Swift that prepares the iOS app icon overlay with ribbon, build type and version (build) info'
  s.homepage                  = 'https://github.com/DanielCech/VersionIcon'
  s.license                   = 'MIT'
  s.author                    = { "Daniel Cech" => "daniel.cech@gmail.com" }
  s.platform                  = :ios, '8.0'
  s.ios.deployment_target     = '8.0'
  s.requires_arc              = true
  s.source                    = { :git => 'https://github.com/strvcom/ios-version-icon.git', :tag => s.version.to_s }
  s.preserve_paths            = 'Bin/**/*'
  s.swift_version             = '4.0'
end
