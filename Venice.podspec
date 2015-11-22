Pod::Spec.new do |s|
  s.name = 'Venice'
  s.version = '0.9'
  s.license = 'MIT'
  s.summary = 'CSP for Swift 2 (Linux ready)'
  s.homepage = 'https://github.com/Zewo/Venice'
  s.authors = { 'Paulo Faria' => 'paulo.faria.rl@gmail.com' }
  s.source = { :git => 'https://github.com/Zewo/Venice.git', :tag => 'v0.9' }

  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.9'

  s.source_files = 'Dependencies/libmill/*.c', 'Venice/**/*.swift'

  s.xcconfig =  {
    'SWIFT_INCLUDE_PATHS' => '$(SRCROOT)/Venice/Dependencies'
  }

  s.preserve_paths = 'Dependencies/*'

  s.requires_arc = true
end