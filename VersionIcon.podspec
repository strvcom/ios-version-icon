Pod::Spec.new do |spec|

  spec.name         = "VersionIcon"
  spec.version      = "0.9.0"
  spec.license      = "Apache License, Version 2.0"

  spec.summary      = "VersionIcon prepares iOS icon with ribbon, text and version info overlay"

  spec.homepage     = "https://github.com/DanielCech/VersionIcon"
  spec.documentation_url = "https://github.com/DanielCech/VersionIcon"
  spec.screenshots  = [ "https://i.ibb.co/4Zgprnc/AppIcon.png" ]

  spec.author             = { "Daniel Čech" => "daniel.cech@gmail.com" }
  spec.social_media_url   = "https://twitter.com/DanielCech"

  spec.requires_arc = true
  spec.source = { :git => "https://github.com/DanielCech/VersionIcon.git", :tag => spec.version.to_s }

  spec.default_subspec = "Bin"
  spec.subspec "Bin" do |ss|
    ss.source_files = "Bin/*.*"
  end

  spec.ios.deployment_target     = '8.0'
  spec.tvos.deployment_target    = '9.0'

end
