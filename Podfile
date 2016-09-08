source 'https://github.com/CocoaPods/Specs.git'

def shared_dependencies
  pod 'AFNetworking', '~> 3'
  pod 'HappyDNS', '>= 0.3'
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
