//
//  ViewController.m
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//
//  出处  http://www.jianshu.com/p/ddb948d8c247

//  本例子是视频采集和音频采集
#import "ViewController.h"
#import "CaptureManager.h"

@interface ViewController ()
{
    
}
@property (nonatomic, strong)UIViewController *viewcontroller;
@property (nonatomic, strong)CaptureManager *manager;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *button = [UIButton buttonWithType: UIButtonTypeCustom];
    [button addTarget:self action:@selector(buttonClickAction) forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor blackColor];
    button.frame = CGRectMake(20, 20, 100, 50);
    [button setTitle:@"Click Me" forState:UIControlStateNormal];
    [self.view addSubview: button];
    
}
#define WeakSelf(type) __weak typeof(type) weak##type = type;

- (void)buttonClickAction{
    self.viewcontroller = [[UIViewController alloc] init];
    UIButton *button = [UIButton buttonWithType: UIButtonTypeCustom];
    [button addTarget:self action:@selector(buttonClickActionDDDD) forControlEvents:UIControlEventTouchUpInside];
    button.frame = CGRectMake(20, 20, 100, 50);
    [button setTitle:@"Back" forState:UIControlStateNormal];
    [self.viewcontroller.view bringSubviewToFront:button];
    [self.viewcontroller.view addSubview: button];
    
    WeakSelf(self);
    [self presentViewController:self.viewcontroller animated:YES completion:^{
        [weakself.manager startCapture:self.viewcontroller.view];
    }];
    
}
- (CaptureManager *)manager{
    if (!_manager) {
        _manager = [[CaptureManager alloc ]init];
    }
    return _manager;
}
- (UIViewController *)viewcontroller{
    if (!_viewcontroller) {
        _viewcontroller = [[UIViewController alloc] init];
    }
    return _viewcontroller;
}
- (void)buttonClickActionDDDD{
    WeakSelf(self);
    [self dismissViewControllerAnimated:YES completion:^{
        [weakself.manager stopCapturing];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
