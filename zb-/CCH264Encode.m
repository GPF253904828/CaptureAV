//
//  CCH264Encode.m
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//

#import "CCH264Encode.h"
#import <VideoToolbox/VideoToolbox.h>
#import <AudioToolbox/AudioToolbox.h>


@interface CCH264Encode ()
{
    int _spsppsFound;
}

@property (nonatomic, assign)VTCompressionSessionRef compressionSessionRef;
@property (nonatomic, assign)int frameIndex;
@property (nonatomic, strong)NSFileHandle *fileHandle;
@property (nonatomic, strong)NSString *documentDictionary;


@end

@implementation CCH264Encode

- (NSFileHandle *)fileHandle{
    if (!_fileHandle) {
        NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject] stringByAppendingPathComponent:@"video.h264"];
        NSLog(@"filePath:%@",filePath);
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isExistPath = [fileManager isExecutableFileAtPath:filePath];
        if (isExistPath) {
            [fileManager removeItemAtPath:filePath error:nil];
        }
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    return _fileHandle;
}

/**
 准备编码

 @param width 采集图像宽
 @param height 高
 */
- (void)prepareEncodeWithWidth:(CGFloat)width height:(CGFloat)height{
    //默认是第0帧
    self.frameIndex = 0;
    
    //创建VTCompressionRef
    
    
    /**
     VTCompressionSessionRef

     @param NULL CFAllocatorRef - CoreFoundation分配内存的模式,NULL默认
     @param width int32_t =视频宽度
     @param height 视频高度
     @param kCMVideoCodecType_H264 CMVideoCodecType - 编码的标准
     @param NULL CFDictionaryRef encoderSpecification
     @param NULL CFDictionaryRef sourceImageBufferAttributes
     @param NULL CFAllocatorRef  compressedDataAllocator
     @param didComparessionCallback VTCompressionOutputCallback - 编码成功后的毁掉函数（C函数）
     @param _Nullable void * - 传递到毁掉函数中的参数
     @return session
     */
    VTCompressionSessionCreate(NULL, width, height,
                               kCMVideoCodecType_H264,
                               NULL, NULL, NULL,
                               didComparessionCallback,
                               (__bridge void* _Nullable)(self),
                               &_compressionSessionRef);
    
    //2. 设置属性
    //2.1 设置实时编码
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    //2.2 设置帧率
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef _Nonnull)@24);
    
    //2.3 设置比特率(码率) 1500000/s
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nonnull)(@[@1500000]));//每秒150万比特bit
    //2.4 关键帧最大间隔, 也就是I帧
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef _Nonnull)(@[@(1500000/8),@1]));//单位是 8byte
    
    //2.5 设置GDP的大小
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nonnull)(@20));
    
    VTCompressionSessionPrepareToEncodeFrames(_compressionSessionRef);
    
    
}


/**
 开始编码

 @param sampleBufferRef CMSampleBufferRef
 */
- (void)encodeFram:(CMSampleBufferRef)sampleBufferRef{
    //2. 开始编码
    //将CMSampleBufferRef 转换成CVImageBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBufferRef);
    CMTime pts = CMTimeMake(self.frameIndex, 24);
    CMTime duration = kCMTimeInvalid;
    VTEncodeInfoFlags flags;
    
    
    VTCompressionSessionEncodeFrame(self.compressionSessionRef,
                                    imageBuffer,
                                    pts,
                                    duration,
                                    NULL,
                                    NULL,
                                    &flags);
    NSLog(@"开始编码一帧数据");
    
}


#pragma mark - 获取编码后的数据    C函数 - 编码后的回调函数

void didComparessionCallback(void *CM_NULLABLE outputCallbackRefCon,
                             void *CM_NULLABLE sourceFrameRefCon,
                             OSStatus status,
                             VTEncodeInfoFlags infoFlags,
                             CM_NULLABLE CMSampleBufferRef sampleBuffer){
    //c语言中不能调用当前self.语法不行，只有通过指针去做相应操作
    //获取当前CCH264Encoder 对象，通过传入的self参数（VTCompressionSessionCreate中传入了self）
    CCH264Encode *encoder = (__bridge CCH264Encode *)(outputCallbackRefCon);
    
    //1判断帧是否为关键帧
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
    BOOL isKeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
    
    //2如果是关键帧 - 获取sps／pps 数据 ，其保存了h264视频的一些必要信息方便解析 - 并且写入文件
    if (isKeyFrame && !encoder -> _spsppsFound) {
        encoder -> _spsppsFound = 1;
        
        //2.1 从CMSampleBufferRef获取CMFormatDescriptionRef
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        //2.2 获取SPS／PPS信息
        const uint8_t *spsOut;
        size_t spsSize, spsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                           0,
                                                           &spsOut,
                                                           &spsSize,
                                                           &spsCount,
                                                           NULL);
        const uint8_t * ppsOut;
        size_t ppsSize, ppsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 
                                                           1,
                                                           &ppsOut,
                                                           &ppsSize,
                                                           &ppsCount,
                                                           NULL);
        //2.3 将SPS／PPS专程NSData，并且写入文件
        NSData *spsData = [NSData dataWithBytes:spsOut length:spsSize];
        NSData *ppsData = [NSData dataWithBytes:ppsOut length:ppsSize];
        
        [encoder writeH264Data:spsData];
        [encoder writeH264Data:ppsData];
    }
    
    //3 获取编码后的数据 写入文件
    //3.1 获取CMBlockBufferRef
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    //3.2 从blockBuffer中获取起始位置的内存地址
    size_t totalLength = 0;
    char *dataPointer;
    CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totalLength, &dataPointer);
    
    //3.3 一帧的图像可能需要写入多个NALU单元 --> Slice切换
    static const int H264HeaderLength = 4;//头部长度一般为4
    size_t bufferOffset = 0;
    while (bufferOffset < totalLength - H264HeaderLength) {
        //3.4 从起始位置拷贝H264HeaderLength长度的地址，计算NALULength
        int NALULength = 0;
        memcpy(&NALULength, dataPointer + bufferOffset, H264HeaderLength);
        
        //H264编码的数据是大端模式（字节序），转化为iOS系统的模式，计算机内一般都是小端，而网络和文件中一般都是大端
        NALULength = CFSwapInt32BigToHost(NALULength);
        
        //3.5 从dataPointer 开始，根据长度创建NSData
        NSData *data = [NSData dataWithBytes:(dataPointer + bufferOffset + H264HeaderLength) length:NALULength];
        //3.6 写入文件
        [encoder writeH264Data:data];
        
        //3.7 重新设置 bufferOffset
        bufferOffset += NALULength + H264HeaderLength;
        
    }
    NSLog(@"////编码出一帧数据");
    
};
- (void)writeH264Data:(NSData *)data{
    //1. 先获取startCode
    const char bytes[] = "\x00\x00\x00\x01";
    
    //2. 获取headerData
    //减一的原因：byts拼接的是字符串，而字符串最后一位有个\0 ； 所以减一才是其正确长度
    NSData *headerData = [NSData dataWithBytes:bytes length:(sizeof(bytes)-1)];
    [self.fileHandle writeData:headerData];
    [self.fileHandle writeData:data];
}


- (void)endEncode{
    VTCompressionSessionInvalidate(self.compressionSessionRef);
    CFRelease(_compressionSessionRef);
}

@end
