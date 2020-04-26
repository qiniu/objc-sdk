//
//  ViewController.m
//  QiniuDemo
//
//  Created by   何舒 on 16/3/2.
//  Copyright © 2016年 Aaron. All rights reserved.
//

#import "ViewController.h"
#import "QNTempFile.h"

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) UIImage *pickImage;
@property (nonatomic, strong) QNConfiguration *config;
@property (nonatomic, strong) QNUploadManager *upManager;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, assign) BOOL isCancel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"七牛云上传";
    self.token = @"bjtWBQXrcxgo7HWwlC_bgHg81j352_GhgBGZPeOW:1BvTH8nslAH4UJXfF_woMUN2g74=:eyJzY29wZSI6InNodWFuZ2h1bzEiLCJkZWFkbGluZSI6MTU4Nzk1MTEwMn0K";
//    self.filePath = [[NSBundle mainBundle] pathForResource:@"IMG_4130" ofType:@"m4v"];
    NSString *cachePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"qiniu"];
    int randomLength = 36 * 1024 * 1024;
    self.filePath = [[QNTempFile createTempfileWithSize:randomLength] path];
    _config = [QNConfiguration build:^(QNConfigurationBuilder *builder) {
//        builder.zone = [QNFixedZone zone1];
//        builder.useConcurrentResumeUpload = YES;
//        builder.concurrentTaskCount = 3;
//        builder.recorder = [QNFileRecorder fileRecorderWithFolder:[[self class] fileCachePath] encodeKey:YES error:nil];
        builder.reportConfig.reportEnable = YES;
        builder.reportConfig.interval = 10;
        builder.reportConfig.uploadThreshold = 100 * 1024;
        builder.reportConfig.maxRecordFileSize = 4 * 1024 * 1024;
        builder.useConcurrentResumeUpload = YES;
        builder.recorder = [QNFileRecorder fileRecorderWithFolder:cachePath error:nil];
    }];
    _upManager = [[QNUploadManager alloc] initWithConfiguration:_config];
}

- (IBAction)chooseAction:(id)sender {
//    [self gotoImageLibrary];
    
    self.isCancel = YES;
}

- (IBAction)uploadAction:(id)sender {
//    if (self.pickImage == nil) {
//        UIAlertView *alert = [[UIAlertView alloc]
//                initWithTitle:@"还未选择图片"
//                      message:@""
//                     delegate:nil
//            cancelButtonTitle:@"OK!"
//            otherButtonTitles:nil];
//        [alert show];
//    } else {
//        [self uploadImageToQNFilePath:[self getImagePath:self.pickImage]];
//    }
    
    for (int i = 0; i < 1; i++) {
        [self startUpload];
    }
}

- (void)startUpload {
    
    [self uploadImageToQNFilePath:self.filePath];
}

+ (NSString *)fileCachePath {
    NSString *cacheDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSString *qiniuPath = [cacheDirectory stringByAppendingPathComponent:@"QiniuUpload"];
    return qiniuPath;
}

- (void)uploadImageToQNFilePath:(NSString *)filePath {

    self.isCancel = NO;
    QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        NSLog(@"percent == %.2f", percent);
    }
                                                                 params:nil
                                                               checkCrc:NO
                                                     cancellationSignal:^BOOL{
        return self.isCancel;
    }];
    [_upManager putFile:filePath key:@"lalala10" token:self.token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"info ===== %@", info);
        NSLog(@"resp ===== %@", resp);
    }
                option:uploadOption];
}

- (void)gotoImageLibrary {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIAlertView *alert = [[UIAlertView alloc]
                initWithTitle:@"访问图片库错误"
                      message:@""
                     delegate:nil
            cancelButtonTitle:@"OK!"
            otherButtonTitles:nil];
        [alert show];
    }
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    self.pickImage = info[UIImagePickerControllerOriginalImage];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
