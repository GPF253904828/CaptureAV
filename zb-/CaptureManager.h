//
//  CaptureManager.h
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface CaptureManager : NSObject


- (void)startCapture:(UIView *)preView;
- (void)stopCapturing;

@end
