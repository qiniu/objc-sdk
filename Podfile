source 'https://github.com/CocoaPods/Specs.git'

<<<<<<< HEAD
target "QiniuSDK iOS" do
  platform :ios, "7.0"
  pod 'AFNetworking', '~> 3'
  pod 'HappyDNS', '>= 0.2'
end

target "QiniuSDK iOSTests" do
  platform :ios, "7.0"
  pod 'AGAsyncTestHelper/Shorthand'
end

target "QiniuSDK Mac" do
  platform :osx, "10.9"
  pod 'AFNetworking', '~> 3'
  pod 'HappyDNS', '>= 0.2'
end

target "QiniuSDK MacTests" do
  platform :osx, "10.9"
  pod 'AGAsyncTestHelper/Shorthand'
=======
def shared_dependencies
  pod "AFNetworking", "~> 2.5.0"
  pod "HappyDNS", ">= 0.3"
end

def test_dependencies
  pod "AGAsyncTestHelper/Shorthand"
end

target "QiniuSDK_iOS" do
  platform :ios, "6.0"
  shared_dependencies
end

target "QiniuSDK_iOSTests" do
  platform :ios, "6.0"
  shared_dependencies
  test_dependencies
end

target "QiniuSDK_Mac" do
  platform :osx, "10.8"
  shared_dependencies
end

target "QiniuSDK_MacTests" do
  platform :osx, "10.8"
  shared_dependencies
  test_dependencies
>>>>>>> 7df8239736fc4228d005e77273ea78d4701e9805
end
