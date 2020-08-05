//
//  ViewController.m
//  QiniuDemo
//
//  Created by   何舒 on 16/3/2.
//  Copyright © 2016年 Aaron. All rights reserved.
//

#import "ViewController.h"
#import "QNTransactionManager.h"

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, weak) IBOutlet UIButton* chooseBtn;
@property (nonatomic, weak) IBOutlet UIButton* uploadBtn;
@property (nonatomic, weak) IBOutlet UIImageView* preViewImage;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;

@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) UIImage *pickImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"七牛云上传";
}

- (IBAction)chooseAction:(id)sender {
    [self gotoImageLibrary];
}

- (IBAction)uploadAction:(id)sender {
    if (self.pickImage == nil) {
        [self alertMessage:@"还未选择图片"];
    } else {
        [self uploadImageToQNFilePath:[self getImagePath:self.pickImage]];
    }
}

- (void)uploadImageToQNFilePath:(NSString *)filePath {
    self.token = @"你的token";
    self.token = @"jH983zIUFIP1OVumiBVGeAfiLYJvwrF45S-t22eu:oIggi3DAgHEMzUmhf_MJRgHYbWc=:eyJzY29wZSI6InpvbmUwLXNwYWNlIiwiZGVhZGxpbmUiOjE1OTczNzgwNTksICJyZXR1cm5Cb2R5Ijoie1wiZm9vXCI6JCh4OmZvbyksIFwiYmFyXCI6JCh4OmJhciksIFwibWltZVR5cGVcIjokKG1pbWVUeXBlKSwgXCJoYXNoXCI6JChldGFnKSwgXCJrZXlcIjokKGtleSksIFwiZm5hbWVcIjokKGZuYW1lKX0ifQ==";
    QNUploadManager *upManager = [[QNUploadManager alloc] init];
    
    __weak typeof(self) weakSelf = self;
    QNUploadOption *uploadOption = [[QNUploadOption alloc] initWithMime:nil progressHandler:^(NSString *key, float percent) {
        NSLog(@"percent == %.2f", percent);
        weakSelf.progressView.progress = percent;
    }
                                                                 params:nil
                                                               checkCrc:NO
                                                     cancellationSignal:nil];
    [upManager putFile:filePath key:nil token:self.token complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"info ===== %@", info);
        NSLog(@"resp ===== %@", resp);
        [self alertMessage:info.message];
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
