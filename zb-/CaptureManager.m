//
//  CaptureManager.m
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//

#import "CaptureManager.h"
#import <AVFoundation/AVFoundation.h>
#import "CCH264Encode.h"
#import "CCAACEncoder.h"


@interface CaptureManager ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>


@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *layer;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) CCH264Encode *videoEncode;
@property (nonatomic, strong) CCAACEncoder *audioEncode;


@end


@implementation CaptureManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (CCH264Encode *)videoEncode{
    if (!_videoEncode) {
        _videoEncode = [[CCH264Encode alloc] init];
    }
    return _videoEncode;
}
- (CCAACEncoder *)audioEncode{
    if (!_audioEncode) {
        _audioEncode = [[CCAACEncoder alloc] init];
    }
    return _audioEncode;
}

/*
 音视频编码方式：
 硬编码：使用非 CPU 进行编码，如利用系统提供的显卡 GPU、专用 DSP 芯片等
 软编码：使用 CPU 进行编码（手机容易发热）
 
 
 */
- (void)startCapture:(UIView *)preView{
    
    //准备编码
    [self.videoEncode prepareEncodeWithWidth:preView.bounds.size.width height:preView.bounds.size.height];
    
    
    /*            采集视频          */
    //创建session 会话
    self.session = [[AVCaptureSession alloc] init];
    _session.sessionPreset = AVCaptureSessionPreset640x480;
    
    NSError *error;
    
    //设置音视频的输入
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&error];
    [self.session addInput:videoInput];
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput *audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    [self.session addInput:audioInput];
    
    //设置音视频的输出
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t videoQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:self queue:videoQueue];
    
    if ([_session canAddOutput:videoOutput]) {
        [_session addOutput:videoOutput];
    }
    
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t audioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:self queue:audioQueue];
    if ([_session canAddOutput:audioOutput]) {
        [_session addOutput:audioOutput];
    }
    
    //获取视频输入与输出链接，用于分辨率音视频数据
    //视频输出方向 默认方向是相反设置方向，必须在将 output 添加到 session中后
    
    AVCaptureConnection * videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    self.videoConnection = videoConnection;
    if (videoConnection.isVideoOrientationSupported) {
        videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
        [self.session commitConfiguration];
    }else{
        NSLog(@"不支持设置方向");
    }
    
    
    
    //添加预览图层
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_session];
    self.layer = layer;
    layer.frame = preView.bounds;
    [preView.layer insertSublayer:layer atIndex:0];
    
    
    //6 开始采集
    [_session startRunning];
}
//丢帧
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
}
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    if (self.videoConnection == connection) {
        dispatch_sync(queue, ^{
            [self.videoEncode encodeFram:sampleBuffer];
        });
        NSLog(@"采集到视频数据");
    }else{
        dispatch_sync(queue, ^{
            [self.audioEncode encodeAAC:sampleBuffer];
        });
        NSLog(@"采集到音频数据");
    }
    NSLog(@"采集到视频画面");
}
- (void)stopCapturing{
    [self.session stopRunning];
    [self.layer removeFromSuperlayer];
    [self.videoEncode endEncode];
    [self.audioEncode endEncodeAAC];
}

@end
