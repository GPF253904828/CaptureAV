//
//  CCH264Encode.h
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface CCH264Encode : NSObject

- (void)prepareEncodeWithWidth:(CGFloat)width height:(CGFloat)height;

- (void)encodeFram:(CMSampleBufferRef)sampleBufferRef;

- (void)endEncode;

@end
