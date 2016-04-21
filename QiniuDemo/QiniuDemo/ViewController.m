//
//  ViewController.m
//  QiniuDemo
//
//  Created by   何舒 on 16/3/2.
//  Copyright © 2016年 Aaron. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"

@interface ViewController () <UINavigationControllerDelegate,
                              UIImagePickerControllerDelegate>

@property(nonatomic, strong) NSString *token;
@property(nonatomic, strong) NSString *domain;
@property(nonatomic, strong) UIImage *pickImage;

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
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:@"还未选择图片"
                                   message:@""
                                  delegate:nil
                         cancelButtonTitle:@"OK!"
                         otherButtonTitles:nil];
    [alert show];
  } else {
    [self getTokenFromQN];
  }
}

- (void)getTokenFromQN {
  // 1.管理器
  AFHTTPRequestOperationManager *manager =
      [AFHTTPRequestOperationManager manager];

  //    //2.设置登录参数
  //    NSDictionary *dict = @{ @"username":@"xn", @"password":@"123" };

  // 3.请求
  [manager POST:@"http://115.231.183.102:9090/api/quick_start/"
                @"simple_image_example_token.php"
      parameters:nil
      success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.domain = responseObject[@"domain"];
        self.token = responseObject[@"uptoken"];
        [self uploadImageToQNFilePath:[self getImagePath:self.pickImage]];
      }
      failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
      }];
}

- (void)uploadImageToQNFilePath:(NSString *)filePath {
  QNUploadManager *upManager = [[QNUploadManager alloc] init];
  QNUploadOption *uploadOption =
      [[QNUploadOption alloc] initWithMime:nil
                           progressHandler:^(NSString *key, float percent) {
                             NSLog(@"percent == %.2f", percent);
                           }
                                    params:nil
                                  checkCrc:NO
                        cancellationSignal:nil];
  [upManager
       putFile:filePath
           key:nil
         token:self.token
      complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
        NSLog(@"info ===== %@", info);
        NSLog(@"resp ===== %@", resp);
        NSLog(@"%@/%@", self.domain, resp[@"key"]);
        [self.preViewImage
             setImageWithURL:
                 [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@",
                                                                 self.domain,
                                                                 resp[@"key"]]]
            placeholderImage:[UIImage imageNamed:@"placeholder.jpg"]];

      }
        option:uploadOption];
}

- (void)gotoImageLibrary {
  if ([UIImagePickerController
          isSourceTypeAvailable:
              UIImagePickerControllerSourceTypePhotoLibrary]) {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
  } else {
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:@"访问图片库错误"
                                   message:@""
                                  delegate:nil
                         cancelButtonTitle:@"OK!"
                         otherButtonTitles:nil];
    [alert show];
  }
}

//再调用以下委托：
#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingImage:(UIImage *)image
                  editingInfo:(NSDictionary *)editingInfo {
  self.pickImage = image; // imageView为自己定义的UIImageView
  [picker dismissViewControllerAnimated:YES
                             completion:^{
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
  NSString *DocumentsPath =
      [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];

  //文件管理器
  NSFileManager *fileManager = [NSFileManager defaultManager];

  //把刚刚图片转换的data对象拷贝至沙盒中
  [fileManager createDirectoryAtPath:DocumentsPath
         withIntermediateDirectories:YES
                          attributes:nil
                               error:nil];
  NSString *ImagePath = [[NSString alloc] initWithFormat:@"/theFirstImage.png"];
  [fileManager
      createFileAtPath:[DocumentsPath stringByAppendingString:ImagePath]
              contents:data
            attributes:nil];

  //得到选择后沙盒中图片的完整路径
  filePath =
      [[NSString alloc] initWithFormat:@"%@%@", DocumentsPath, ImagePath];
  return filePath;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
