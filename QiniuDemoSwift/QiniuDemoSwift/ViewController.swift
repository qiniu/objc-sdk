//
//  ViewController.swift
//  QiniuDemoSwift
//
//  Created by yangsen on 2021/4/19.
//

import UIKit
import Photos
import ZLPhotoBrowser
import Qiniu

class ViewController: UIViewController {

    var asset : PHAsset? = nil
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func upload(_ sender: UIButton) {
//        let token = "dxVQk8gyk3WswArbNhdKIwmwibJ9nFsQhMNUmtIM:CVsHrY_-O99lhX-_NwdJL8w9oKo=:eyJzY29wZSI6ImtvZG8tcGhvbmUtem9uZTAtc3BhY2UiLCJkZWFkbGluZSI6MTYyNDE3MjcwOCwgInJldHVybkJvZHkiOiJ7XCJjYWxsYmFja1VybFwiOlwiaHR0cDpcL1wvY2FsbGJhY2suZGV2LnFpbml1LmlvXCIsIFwiZm9vXCI6JCh4OmZvbyksIFwiYmFyXCI6JCh4OmJhciksIFwibWltZVR5cGVcIjokKG1pbWVUeXBlKSwgXCJoYXNoXCI6JChldGFnKSwgXCJrZXlcIjokKGtleSksIFwiZm5hbWVcIjokKGZuYW1lKX0ifQ=="
//        let uploader = QNUploadManager(configuration: nil)
//        uploader?.put(asset, key: "iOS-demo-test", token: token, complete: { (response, key, responseData) in
//            if response?.isOK == true {
//                print("upload success")
//            } else {
//                print("upload fail")
//            }
//        }, option: QNUploadOption.defaultOptions())

        let r = PHAssetResource.assetResources(for: self.asset!)
        let file = try? QNPHAssetResource(r.first)
        print("\(String(describing: file?.description))")
    }
    
    @IBAction func selectImage(_ sender: Any) {
        let ps = ZLPhotoPreviewSheet()
        ps.selectImageBlock = { [weak self] (images, assets, isOriginal) in
            // your code
            if assets.count > 0 {
                self?.asset = assets[0]
            }
            if images.count > 0 {
                self?.imageView.image = images[0]
            }
        }
        ps.showPreview(animate: true, sender: self)
    }

}

