//
//  ViewController.m
//  MLQRcodeScan
//
//  Created by emily on 17/3/6.
//  Copyright © 2017年 emily. All rights reserved.
//

#import "ViewController.h"
#import "QRScanViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(SCREEN_WIDTH/2-100/2, 100, 100, 50);
    [button setTitle:@"按下" forState:0];
    button.backgroundColor = [UIColor redColor];
    [button addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    
}

-(void)buttonAction:(UIButton *)sender{
    //二维码扫描测试
    QRScanViewController *scanVc  = [[QRScanViewController alloc] init];
    [self.navigationController pushViewController:scanVc animated:YES];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
