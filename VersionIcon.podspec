Pod::Spec.new do |s|
 s.name = 'VersionIcon'
 s.version = '0.9.1'
 s.license = 'Apache License, Version 2.0'
 s.summary = 'VersionIcon prepares iOS icon with ribbon, text and version info overlay'
 s.homepage = 'https://github.com/DanielCech/VersionIcon'
 s.social_media_url = 'https://twitter.com/DanielCech'
 s.authors = { "Daniel Čech": "daniel.cech@gmail.com" }
 s.source = { :git => "https://github.com/DanielCech/VersionIcon.git", :tag => +s.version.to_s }
 s.platforms = { :ios => "11.0", :osx => "10.10", :tvos => "11.0", :watchos => "2.0" }
 s.requires_arc = true

 s.default_subspec = "Core"
 s.subspec "Core" do |ss|
     ss.source_files  = "Bin/*"
     ss.framework  = "Foundation"
 end
end
