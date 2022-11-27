#
# Be sure to run `pod lib lint OrionWebRTC.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OIWebRTC'
  s.version          = '0.105.0'
  s.summary          = 'OIWebRTC Framework.'
  s.homepage         = 'https://github.com/OrionInnovationTRTech/webRTC-iOS-Release'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'brtgmaden' => 'brtgmaden@hotmail.com' }
  s.source            = { :git => 'https://github.com/OrionInnovationTRTech/webRTC-iOS-Release.git', :tag => '0.105.0'}
  s.vendored_frameworks = 'WebRTC.xcframework'

  s.ios.deployment_target = '10.0'

  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }

end
