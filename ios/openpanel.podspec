#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint openpanel.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'openpanel'
  s.version          = '0.1.0'
  s.summary          = 'OpenPanel analytics for Flutter.'
  s.description      = <<-DESC
OpenPanel analytics for Flutter with a native iOS Swift client,
persistent offline event queue and batching.
                       DESC
  s.homepage         = 'https://github.com/coolswood/openpanel'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'coolswood' => 'https://github.com/coolswood' }
  s.source           = { :path => '.' }
  s.source_files = 'openpanel/Sources/openpanel/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'openpanel_privacy' => ['openpanel/Sources/openpanel/PrivacyInfo.xcprivacy']}
end
