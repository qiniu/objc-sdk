source 'https://github.com/CocoaPods/Specs.git'

def shared_dependencies
  pod 'HappyDNS', :git => 'https://github.com/YangSen-qn/happy-dns-objc.git', :tag => 'v0.3.17'
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
