//
//  CCAACEncoder.h
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface CCAACEncoder : NSObject

- (void)encodeAAC:(CMSampleBufferRef)sampleBuffer;

- (void)endEncodeAAC;

@end
