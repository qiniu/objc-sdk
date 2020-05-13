#!/bin/bash

set -o errexit
set -o pipefail
set -x

LOSSRATE=$1

inject-network-loss(){
    sudo dnctl pipe 1 config plr $1
    echo "dummynet in proto tcp from any to any pipe 1" > pf.conf
    echo "dummynet out proto tcp from any to any pipe 1" >> pf.conf
    sudo pfctl -f pf.conf
}

info(){
  echo -e "[$(date +'%Y-%m-%dT%H:%M:%S.%N%z')] INFO: $@" >&1
}

info "enable pf"
sudo pfctl -e

info "inject network loss 0.01"
inject-network-loss 0.01

info "run unit test"
xcodebuild test -workspace QiniuSDK.xcworkspace -scheme QiniuSDK_iOS -configuration Release -destination 'platform=iOS Simulator,OS=12.4,name=iPhone Xs Max' -only-testing:QiniuSDK_iOSTests/QNFormUploadTest/test100Up 


info "inject network loss 0.1"
inject-network-loss 0.1

info "run unit test"
xcodebuild test -workspace QiniuSDK.xcworkspace -scheme QiniuSDK_iOS -configuration Release -destination 'platform=iOS Simulator,OS=12.4,name=iPhone Xs Max' -only-testing:QiniuSDK_iOSTests/QNFormUploadTest/test100Up 

info "inject network loss 0.2"
inject-network-loss 0.2

info "run unit test"
xcodebuild test -workspace QiniuSDK.xcworkspace -scheme QiniuSDK_iOS -configuration Release -destination 'platform=iOS Simulator,OS=12.4,name=iPhone Xs Max' -only-testing:QiniuSDK_iOSTests/QNFormUploadTest/test100Up 

info "inject network loss 0.5"
inject-network-loss 0.5

info "run unit test"
xcodebuild test -workspace QiniuSDK.xcworkspace -scheme QiniuSDK_iOS -configuration Release -destination 'platform=iOS Simulator,OS=12.4,name=iPhone Xs Max' -only-testing:QiniuSDK_iOSTests/QNFormUploadTest/test100Up 
