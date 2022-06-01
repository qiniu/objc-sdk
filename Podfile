source 'https://github.com/CocoaPods/Specs.git'

def shared_dependencies
  pod 'HappyDNS', '~> 1.0.1'
 # pod 'HappyDNS', :path => '../HappyDns_iOS'
end

def test_dependencies
  pod 'AGAsyncTestHelper/Shorthand'
end

target 'QiniuSDK_iOS' do
  platform :ios, '7.0'
  shared_dependencies
end

target 'QiniuSDK_iOSTests' do
  platform :ios, '7.0'
  shared_dependencies
  test_dependencies
end

target 'QiniuSDK_Mac' do
  platform :osx, '10.9'
  shared_dependencies
end

target 'QiniuSDK_MacTests' do
  platform :osx, '10.9'
  shared_dependencies
  test_dependencies
end
