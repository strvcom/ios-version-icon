Pod::Spec.new do |s|
  s.name                      = 'VersionIcon'
  s.module_name               = 'VersionIcon'
  s.version                   = '1.0.2'
  s.summary                   = 'Script written in Swift that prepares the iOS app icon overlay with ribbon, build type and version (build) info'
  s.homepage                  = 'https://github.com/DanielCech/VersionIcon'
  s.license                   = 'MIT'
  s.author                    = { "Daniel Cech" => "daniel.cech@gmail.com" }
  s.platform                  = :ios, '8.0'
  s.ios.deployment_target     = '8.0'
  s.requires_arc              = true
  s.source                    = { :git => 'https://github.com/DanielCech/VersionIcon.git', :tag => s.version.to_s }
  # s.source_files              = 'Bin/**/*'
  # s.resource_bundle           = { 'PKHUDResources' => 'PKHUD/*.xcassets' }
  s.preserve_paths            = 'Bin/**/*'
  s.swift_version             = '4.0'
end
