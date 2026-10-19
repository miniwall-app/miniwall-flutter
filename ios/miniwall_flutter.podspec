Pod::Spec.new do |s|
  s.name             = 'miniwall_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Miniwall for Flutter (iOS side).'
  s.homepage         = 'https://docs.miniwall.app'
  s.license          = { :type => 'MIT' }
  s.author           = 'Miniwall'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'MiniwallSDK', '~> 0.1'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.9'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
