Pod::Spec.new do |s|
  s.name             = "objcTox"
  s.version          = "0.7.1"
  s.summary          = "Objective-C wrapper for Tox"
  s.homepage         = "https://github.com/wcdmac/objcTox"
  s.license          = "MIT"
  s.author           = { "Dmytro Vorobiev" => "d@dvor.me" }
  s.source           = {
      :git => "https://github.com/wcdmac/objcTox.git",
      :branch => "group-chat-support"
  }
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'
  s.requires_arc = true
  s.source_files = 'Classes/**/*.{m,h}'
  s.public_header_files = 'Classes/Public/**/*.h'
  s.dependency 'toxcore', :git => 'https://github.com/wcdmac/toxcore.git', :tag => '0.2.20'
  s.dependency 'TPCircularBuffer', '~> 0.0.1'
  s.dependency 'CocoaLumberjack', '1.9.2'
  s.dependency 'Realm', '3.1.0'
  s.resource_bundle = {
      'objcTox' => 'Classes/Public/Manager/nodes.json'
  }
end