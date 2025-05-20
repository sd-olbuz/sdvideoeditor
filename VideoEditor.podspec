Pod::Spec.new do |s|
  s.name             = 'SDVideoEditor'
  s.version          = '1.0.0'
  s.summary          = 'A powerful video editing library for iOS'
  s.description      = <<-DESC
SDVideoEditor is a comprehensive video editing library for iOS that provides features like:
- Video trimming
- Speed control
- Filter application
- Brightness, contrast, and saturation adjustments
- Face blur functionality
                       DESC

  s.homepage         = 'https://github.com/sd-olbuz/sdvideoeditor.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Saurav' => 'your.email@example.com' }
  s.source           = { :git => 'https://github.com/sd-olbuz/sdvideoeditor.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/yourusername'

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  s.source_files = 'VideoEditor/**/*.{swift,h,m}'
  s.resources = 'VideoEditor/**/*.{xib,storyboard,xcassets}'

  s.frameworks = 'UIKit', 'AVFoundation', 'CoreImage', 'Vision'
  s.dependency 'SnapKit', '~> 5.0.0'
end 