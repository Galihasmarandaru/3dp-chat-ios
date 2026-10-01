# Uncomment the next line to define a global platform for your project
platform :ios, '17.0'

target 'Example' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Example
  pod "imi-dolphin-livechat-ios", :path => "../imi-dolphin-livechat-ios/"

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
