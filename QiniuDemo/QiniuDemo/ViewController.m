//
//  ViewController.m
//  QiniuDemo
//
//  Created by   何舒 on 16/3/2.
//  Copyright © 2016年 Aaron. All rights reserved.
//

#import "Configure.h" // 测试参数配置，暂时只有token，可删除
#import "ViewController.h"
#import "QNTransactionManager.h"
#import <Photos/Photos.h>

typedef NS_ENUM(NSInteger, UploadState){
    UploadStatePrepare,
    UploadStateUploading,
    UploadStateCancelling
};

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, weak) IBOutlet UIButton* chooseBtn;
@property (nonatomic, weak) IBOutlet UIButton* uploadBtn;
@property (nonatomic, weak) IBOutlet UIImageView* preViewImage;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@property (nonatomic, assign) UploadState uploadState;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) UIImage *pickImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [QNLogUtil setLogLevel:QNLogLevelInfo];
    
    // Do any additional setup after loading the view, typically from a nib.
    [self changeUploadState:UploadStatePrepare];
    self.title = @"七牛云上传";
}

- (IBAction)chooseAction:(id)sender {
    [self gotoImageLibrary];
}

- (IBAction)uploadAction:(UIButton *)sender {
    if (self.uploadState == UploadStatePrepare) {
    
#ifdef YourToken
        NSString *path = [[NSBundle mainBundle] pathForResource:@"UploadResource.dmg" ofType:nil];
        path = [[NSBundle mainBundle] pathForResource:@"UploadResource_49M.zip" ofType:nil];
//        path = [[NSBundle mainBundle] pathForResource:@"UploadResource_1.44G.zip" ofType:nil];
        
//        NSFileManager *manager = [NSFileManager defaultManager];
//        NSURL *desktopUrl = [manager URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask].firstObject;
//        path = [desktopUrl URLByAppendingPathComponent:@"pycharm.dmg"].path;
        
        [self uploadImageToQNFilePath:path];
        [self changeUploadState:UploadStateUploading];
#else
        if (self.pickImage == nil) {
            [self alertMessage:@"还未选择图片"];
        } else {
            [self uploadImageToQNFilePath:[self getImagePath:self.pickImage]];
            [self changeUploadState:UploadStateUploading];
        }
#endif
        
    } else {
        [self changeUploadState:UploadStateCancelling];
    }
}

- (void)changeUploadState:(UploadState)uploadState{
    
    self.uploadState = uploadState;
    if (uploadState == UploadStatePrepare) {
        [self.uploadBtn setTitle:@"上传" forState:UIControlStateNormal];
        self.uploadBtn.enabled = true;
    } else if (uploadState == UploadStateUploading) {
        [self.uploadBtn setTitle:@"取消上传" forState:UIControlStateNormal];
        self.uploadBtn.enabled = true;
    } else {
        [self.uploadBtn setTitle:@"取消上传" forState:UIControlStateNormal];
        self.uploadBtn.enabled = false;
    }
}

- (void)uploadImageToQNFilePath:(NSString *)filePath {
    
    self.token = YourToken;
    QNConfiguration *configuration = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
        builder.useConcurrentResumeUpload = NO;
        builder.resumeUploadVersion = QNResumeUploadVersionV1;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] error:nil];
    }];
    QNUploadManager *upManager = [[QNUploadManager alloc] initWithConfiguration:configuration];
    
    __weak typeof(self) weakSelf = self;
    QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        NSLog(@"percent == %.2f", percent);
        weakSelf.progressView.progress = percent;
    }
                                                                 params:nil
                                                               checkCrc:NO
                                                     cancellationSignal:^BOOL{
        return weakSelf.uploadState == UploadStateCancelling;
    }];
    
//    [upManager putFile:filePath key:@"DemoResource" token:self.token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
//        NSLog(@"info ===== %@", info);
//        NSLog(@"resp ===== %@", resp);
//
//        [weakSelf changeUploadState:UploadStatePrepare];
//        [weakSelf alertMessage:info.message];
//    }
//                option:uploadOption];
    
    long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:filePath];
    [upManager putInputStream:stream sourceId:filePath.lastPathComponent size:fileSize fileName:filePath.lastPathComponent key:@"DemoResource_1.44G" token:self.token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"info ===== %@", info);
        NSLog(@"resp ===== %@", resp);

        [weakSelf changeUploadState:UploadStatePrepare];
        [weakSelf alertMessage:info.message];
    } option:uploadOption];
    
//    NSURL *url = [NSURL fileURLWithPath:filePath];
//    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
//    PHAsset *asset = fetchResult.firstObject;
//    [upManager putPHAsset:asset key:@"DemoResource" token:self.token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
//        NSLog(@"info ===== %@", info);
//        NSLog(@"resp ===== %@", resp);
//
//        [weakSelf changeUploadState:UploadStatePrepare];
//        [weakSelf alertMessage:info.message];
//    }
//                option:uploadOption];
}

- (void)gotoImageLibrary {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [self alertMessage:@"访问图片库错误"];
    }
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    self.pickImage = info[UIImagePickerControllerOriginalImage];
    self.preViewImage.image = self.pickImage;
    [picker dismissViewControllerAnimated:YES completion:^{
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

//照片获取本地路径转换
- (NSString *)getImagePath:(UIImage *)Image {
    NSString *filePath = nil;
    NSData *data = nil;
    if (UIImagePNGRepresentation(Image) == nil) {
        data = UIImageJPEGRepresentation(Image, 1.0);
    } else {
        data = UIImagePNGRepresentation(Image);
    }

    //图片保存的路径
    //这里将图片放在沙盒的documents文件夹中
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];

    //文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];

    //把刚刚图片转换的data对象拷贝至沙盒中
    [fileManager createDirectoryAtPath:DocumentsPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *ImagePath = [[NSString alloc] initWithFormat:@"/theFirstImage.png"];
    [fileManager createFileAtPath:[DocumentsPath stringByAppendingString:ImagePath] contents:data attributes:nil];

    //得到选择后沙盒中图片的完整路径
    filePath = [[NSString alloc] initWithFormat:@"%@%@", DocumentsPath, ImagePath];
    return filePath;
}


- (void)alertMessage:(NSString *)message{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:message
                                                    message:@""
                                                   delegate:nil
                                          cancelButtonTitle:@"OK!"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
