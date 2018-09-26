//
//  QRScanViewController.m
//  TaiRunMall
//
//  Created by emily on 17/2/6.
//  Copyright © 2017年 emily. All rights reserved.
//

#import "QRScanViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ScanSuccessJumpVC.h"

@interface QRScanViewController ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>{
    
    int num;
    BOOL upOrdown;
    NSTimer *timer;
    CAShapeLayer *cropLayer;
    
}

@property (nonatomic,strong) AVCaptureDevice *device; //获取摄像设备
@property (nonatomic,strong) AVCaptureDeviceInput *input;//输入流
@property (nonatomic,strong) AVCaptureMetadataOutput *output;//输出流
@property (nonatomic,strong) AVCaptureSession *session; //输入输出的中间桥梁
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;// 预览图层

@property (nonatomic,strong)UIImageView *line; //扫描线条

@end

@implementation QRScanViewController

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self setCropRect:kScanRect];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self removeCAShapeLayer];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configView];
   
    //判断应用是否有相机
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device==nil) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"设备没有摄像头" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
           
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    //如果有相机看是否有访问权限
    //判断用户的权限
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied) {

        //无权限时做一个友好的提示
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"温馨提示" message:@"请您设置允许app访问您的相机\n设置>隐私>相机" preferredStyle:UIAlertControllerStyleAlert];
        //好
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        //去设置
        UIAlertAction *settingAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            //通过使用多线程延迟调用
            dispatch_after(0.1, dispatch_get_main_queue(), ^{
                //跳转到系统设置
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
                
                //        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"prefs:root=Privacy&path=CAMERA"]];
            });
        }];
        [alertController addAction:okAction];
        [alertController addAction:settingAction];
        [self presentViewController:alertController animated:YES completion:nil];
        return;
    }else{
        //调用相机
        [self startScan];

    }
    
    
}
-(void)configView{
    
    
    upOrdown = NO;
    num =0;
    _line = [[UIImageView alloc] initWithFrame:CGRectMake(LEFT, TOP+10, 220, 2)];
    _line.image = [UIImage imageNamed:@"line.png"];
    [self.view addSubview:_line];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(animation1) userInfo:nil repeats:YES];
    
    //返回按钮
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(20, 20,40, 40);
    [backButton setTitle:@"back" forState:0];
    [backButton setTitleColor:[UIColor whiteColor] forState:0];
    [self.view addSubview:backButton];
    [backButton addTarget:self action:@selector(backButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    //闪光灯
    UIButton *flashlightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    flashlightButton.frame = CGRectMake(SCREEN_WIDTH - 60, 20,50, 40);
    flashlightButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [flashlightButton setTitle:@"闪光灯" forState:0];
    [flashlightButton setTitleColor:[UIColor whiteColor] forState:0];
    [self.view addSubview:flashlightButton];
    [flashlightButton addTarget:self action:@selector(flashlightButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    //扫描范围边框
    UIImageView * imageView = [[UIImageView alloc]initWithFrame:kScanRect];
    imageView.image = [UIImage imageNamed:@"pick_bg"];
    [self.view addSubview:imageView];
    //提示文字
    UILabel *showLabel = [[UILabel alloc] initWithFrame:CGRectMake(imageView.frame.origin.x,imageView.frame.origin.y+imageView.frame.size.height+10, 220, 18)];
    showLabel.font = [UIFont systemFontOfSize:12];
    showLabel.textColor = [UIColor whiteColor];
    showLabel.textAlignment = NSTextAlignmentCenter;
    showLabel.text = @"将二维码/条码放入框内, 即可自动扫描";
    [self.view addSubview:showLabel];
    //放组件的底部View
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT-80, SCREEN_WIDTH, 80)];
    bottomView.backgroundColor = [UIColor blackColor];
    bottomView.alpha = 0.6f;
    [self.view addSubview:bottomView];
    
    NSArray *titleArray = @[@"相册",@"闪光灯",@"我的二维码"];
    
    for (int i = 0; i < 3; i++) {
        UIButton *photoButton = [UIButton buttonWithType:UIButtonTypeCustom];
        photoButton.frame = CGRectMake(i*bottomView.frame.size.width/3, 0, bottomView.frame.size.width/3, bottomView.frame.size.height);
        [photoButton setTitle:titleArray[i] forState:0];
        [photoButton setTitleColor:[UIColor whiteColor] forState:0];
        [bottomView addSubview:photoButton];
        [photoButton addTarget:self action:@selector(photoButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        photoButton.tag = 100+i;
    }
    
    
}
#pragma mark ------底部三个按钮的点击响应事件------
-(void)photoButtonAction:(UIButton *)sender{
    switch (sender.tag) {
        case 100:
        {
            NSLog(@"我的相册");
            [self readImageFromAlbum];
        }
            break;
        case 101:{
            
        }
            break;
        case 102:{
            
        }
            break;
        default:
            break;
    }
}


#pragma mark - - - 从相册中读取照片
- (void)readImageFromAlbum {
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        //1.初始化相册拾取器
        UIImagePickerController *controller = [[UIImagePickerController alloc] init];
        //2.设置代理
        controller.delegate = self;
        //3.设置资源：
        controller.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        //4.随便给他一个转场动画
//        controller.modalTransitionStyle=UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:controller animated:YES completion:NULL];
        
    }else{
        
        UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"提示" message:@"设备不支持访问相册，请在设置->隐私->照片中进行设置！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [alert show];
    }
}
#pragma mark -------实现imagePickerController代理------
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSLog(@"info - - - %@", info);
    //1.获取选择的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    //2.初始化一个监测器
    // CIDetector(CIDetector可用于人脸识别)进行图片解析，从而使我们可以便捷的从相册中获取到二维码
    // 声明一个CIDetector，并设定识别类型 CIDetectorTypeQRCode
    CIDetector*detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    
    [picker dismissViewControllerAnimated:YES completion:^{
        //监测到的结果数组
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
        if (features.count >=1) {
            /**结果对象 */
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            NSString *scannedResult = feature.messageString;
            ScanSuccessJumpVC *jumpVC = [[ScanSuccessJumpVC alloc] init];
            jumpVC.jump_URL = scannedResult;
            [self.navigationController pushViewController:jumpVC animated:YES];
            
        }
        else{
            UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"提示" message:@"该图片没有包含一个二维码！" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            [alertView show];
            
        }
        
        
    }];

}
#pragma mark -------返回事件------
-(void)backButtonAction:(UIButton *)sender{
    [self.navigationController popViewControllerAnimated:YES];
}
#pragma mark ----------闪光灯事件 -------
-(void)flashlightButtonAction:(UIButton *)sender{
    NSLog(@"闪光灯");
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self turnTorchOn:YES];
    }
    else{
        [self turnTorchOn:NO];
    }
}

#pragma mark-> 开关闪光灯
- (void)turnTorchOn:(BOOL)on
{
    
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if ([device hasTorch] && [device hasFlash]){
            
            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
            }
            [device unlockForConfiguration];
        }
    }
}
-(void)animation1
{
    if (upOrdown == NO) {
        num ++;
        _line.frame = CGRectMake(LEFT, TOP+10+2*num, 220, 2);
        if (2*num == 200) {
            upOrdown = YES;
        }
    }
    else {
        num --;
        _line.frame = CGRectMake(LEFT, TOP+10+2*num, 220, 2);
        if (num == 0) {
            upOrdown = NO;
        }
    }
    
}

-(void)startScan{
    
    // Device
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Input
    _input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    
    // Output
    _output = [[AVCaptureMetadataOutput alloc]init];
     //设置代理 在主线程里刷新
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    //设置扫描区域
    CGFloat top = TOP/SCREEN_HEIGHT;
    CGFloat left = LEFT/SCREEN_WIDTH;
    CGFloat width = 220/SCREEN_WIDTH;
    CGFloat height = 220/SCREEN_HEIGHT;
    ///top 与 left 互换  width 与 height 互换
    [_output setRectOfInterest:CGRectMake(top,left, height, width)];
    
    
    // Session
    _session = [[AVCaptureSession alloc]init];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    //1.判断输入能否添加到会话中
    if ([_session canAddInput:self.input])
    {
        [_session addInput:self.input];
    }
    // 2.判断输出能够添加到会话中
    if ([_session canAddOutput:self.output])
    {
        [_session addOutput:self.output];
    }
    
    // 条码类型 AVMetadataObjectTypeQRCode
    // 3.设置输出能够解析的数据类型
    //注意点: 设置数据类型一定要在输出对象添加到会话之后才能设置
    [_output setMetadataObjectTypes:[NSArray arrayWithObjects:AVMetadataObjectTypeQRCode, nil]];
    //设置扫码支持的编码格式(如下设置条形码和二维码兼容)
    _output.metadataObjectTypes=@[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    
    // Preview
    // 4.添加预览图层，传递_session是为了告诉图层将来显示什么内容
    _previewLayer =[AVCaptureVideoPreviewLayer layerWithSession:_session];
    
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewLayer.frame =self.view.layer.bounds;
    [self.view.layer insertSublayer:_previewLayer atIndex:0];
    
    // 5.开始扫描
    [_session startRunning];

}
#pragma mark ------实现代理方法--------
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    NSString *stringValue;
    
    if ([metadataObjects count] >0)
    {
        //停止扫描
        [_session stopRunning];
        [[self.previewLayer connection] setEnabled:NO];
        [timer setFireDate:[NSDate distantFuture]];
        [_line removeFromSuperview];
        _line = nil;
        double delayInSeconds = 2.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW,
                                                (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [[self.previewLayer connection] setEnabled:YES];
            [_session startRunning];
            
        });
        
        AVMetadataMachineReadableCodeObject * metadataObject = [metadataObjects objectAtIndex:0];
        stringValue = metadataObject.stringValue;
        NSLog(@"扫描结果：%@",stringValue);
        
//        NSArray *arry = metadataObject.corners;
//        for (id temp in arry) {
//            NSLog(@"%@",temp);
//        }
        
        if ([metadataObject.stringValue hasPrefix:@"http"]) {
            
            ScanSuccessJumpVC *jumpVC = [[ScanSuccessJumpVC alloc] init];
            jumpVC.jump_URL = metadataObject.stringValue;
            NSLog(@"stringValue = = %@", metadataObject.stringValue);
            [self.navigationController pushViewController:jumpVC animated:YES];
            
        } else { // 扫描结果为条形码
            
            ScanSuccessJumpVC *jumpVC = [[ScanSuccessJumpVC alloc] init];
            jumpVC.jump_bar_code = metadataObject.stringValue;
            NSLog(@"stringValue = = %@", metadataObject.stringValue);
            [self.navigationController pushViewController:jumpVC animated:YES];
        }
        
        
    } else {
        NSLog(@"无扫描信息");
        return;
    }
}
- (void)setCropRect:(CGRect)cropRect{
    cropLayer = [[CAShapeLayer alloc] init];
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, nil, cropRect);
    CGPathAddRect(path, nil, self.view.bounds);
    
    [cropLayer setFillRule:kCAFillRuleEvenOdd];
    [cropLayer setPath:path];
    [cropLayer setFillColor:[UIColor blackColor].CGColor];
    [cropLayer setOpacity:0.6];
    
    
    [cropLayer setNeedsDisplay];
    
    [self.view.layer addSublayer:cropLayer];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
#pragma mark - - - 移除
- (void)removeCAShapeLayer {
    [cropLayer removeFromSuperlayer];

}


@end
