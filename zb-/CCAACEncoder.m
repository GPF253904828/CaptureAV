//
//  CCAACEncoder.m
//  zb-
//
//  Created by GPF on 2017/4/21.
//  Copyright © 2017年 Damon. All rights reserved.
//

#import "CCAACEncoder.h"


@interface CCAACEncoder ()


@property (nonatomic, assign) AudioConverterRef audioConverter;
@property (nonatomic, assign)uint8_t *aacBuffer;
@property (nonatomic, assign)NSUInteger aacBufferSize;
@property (nonatomic, assign)char * pcmBuffer;
@property (nonatomic, assign)size_t pcmBufferSize;
@property (nonatomic, strong)NSFileHandle *audioFileHandle;

@end

@implementation CCAACEncoder

- (void)dealloc
{
    AudioConverterDispose(_audioConverter);
    free(_aacBuffer);
}
- (NSFileHandle *)audioFileHandle{
    if (!_audioFileHandle) {
        NSString *audioFile = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject] stringByAppendingPathComponent:@"audio.aac"];
        [[NSFileManager defaultManager] removeItemAtPath:audioFile error:nil];
        [[NSFileManager defaultManager] createFileAtPath:audioFile contents:nil attributes:nil];
        _audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:audioFile];
    }
    return _audioFileHandle;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioConverter = NULL;
        _pcmBufferSize = 0;
        _pcmBuffer = NULL;
        _aacBufferSize = 1024;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
        memset(_aacBuffer, 0, _aacBufferSize);
    }
    return self;
}
- (void)encodeAAC:(CMSampleBufferRef)sampleBuffer{
    CFRetain(sampleBuffer);
    //1. 创建audio encode converter
    if (!_audioConverter) {
        AudioStreamBasicDescription inputAudioStreamBasicDesciription = *CMAudioFormatDescriptionGetStreamBasicDescription((CMAudioFormatDescriptionRef)CMSampleBufferGetFormatDescription(sampleBuffer));
        
        AudioStreamBasicDescription outputAudioStreamBasicDescription = {
            .mSampleRate = inputAudioStreamBasicDesciription.mSampleRate,
            .mFormatID = kAudioFormatMPEG4AAC,
            .mFormatFlags = kMPEG4Object_AAC_LC,
            .mBytesPerPacket = 0,
            .mFramesPerPacket = 1024,
            .mBytesPerFrame = 0,
            .mChannelsPerFrame = 1,
            .mBitsPerChannel = 0,
            .mReserved = 0
        };
        static AudioClassDescription description;
        UInt32 encoderSpecifier = kAudioFormatMPEG4AAC;
        
        UInt32 size;
        AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                   sizeof(encoderSpecifier),
                                   &encoderSpecifier,
                                   &size);
        unsigned int cout = size / sizeof(AudioClassDescription);
        AudioClassDescription descriptions[cout];
        AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descriptions);
        for (unsigned int i=0 ; i<cout ; i++) {
            if ((kAudioFormatMPEG4AAC == descriptions[i].mSubType) && (kAppleSoftwareAudioCodecManufacturer == descriptions[i].mManufacturer)) {
                memcpy(&description, &(descriptions[i]), sizeof(description));
            }
        }
        
        AudioConverterNewSpecific(&inputAudioStreamBasicDesciription,
                                  &outputAudioStreamBasicDescription,
                                  1,
                                  &description,
                                  &_audioConverter);
        
    }
    
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    CFRetain(blockBuffer);
    OSStatus status = CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &_pcmBufferSize, &_pcmBuffer);
    NSError *error = nil;
    if (status != kCMBlockBufferNoErr) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    memset(_aacBuffer, 0, _aacBufferSize);
    AudioBufferList outAudioBufferList = {0};
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = 1;
    outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
    outAudioBufferList.mBuffers[0].mData = _aacBuffer;
    AudioStreamPacketDescription *outPacketDescription = NULL;
    UInt32 ioOutputDataPacketSize = 1;
    status = AudioConverterFillComplexBuffer(_audioConverter, inInputDataProc, (__bridge void *)(self),&ioOutputDataPacketSize, &outAudioBufferList, outPacketDescription);
    if (status == 0) {
        NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
        NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
        NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
        [fullData appendData:rawAAC];
        [self.audioFileHandle writeData:fullData];
    }else{
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
}


/**
 编码器回调 C函数

 @param inAudioConverter x
 @param ioNumberDataPackets c
 @param ioData x
 @param outDataPacketDescription x
 @param inUserData x
 @return x
 */
OSStatus inInputDataProc(AudioConverterRef inAudioConverter,
                         UInt32 *ioNumberDataPackets,
                         AudioBufferList *ioData,
                         AudioStreamPacketDescription **outDataPacketDescription,
                         void *inUserData){
    CCAACEncoder *encoder = (__bridge CCAACEncoder *)(inUserData);
    UInt32 requestedPackets = *ioNumberDataPackets;
    
    //填充PCM到缓冲区
    size_t copiedSamples = encoder.pcmBufferSize;
    ioData ->mBuffers[0].mData = encoder.pcmBuffer;
    ioData ->mBuffers[0].mDataByteSize = (int)encoder.pcmBufferSize;
    encoder.pcmBufferSize = 0;
    encoder.pcmBuffer = NULL;
    if (copiedSamples < requestedPackets) {
        //PCM 缓冲期还没有满
        *ioNumberDataPackets = 0;
        return -1;
    }
    *ioNumberDataPackets = 1;
    return noErr;
}

- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength{
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    
    int profile = 2;//AAC LC
    
    int freqIdx = 4;//44.1KHz
    int chanCfg = 1;//MPEG-4 Audio Channel Configuration. 1Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    packet[0] = (char)0xFF;//11111111 = syncword
    packet[1] = (char)0xF9;//1111 1 00 1 = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile - 1) << 6) + (freqIdx << 2 ) + (chanCfg >> 2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    
    return data;
}

- (void)endEncodeAAC{
    AudioConverterDispose(_audioConverter);
    _audioConverter = nil;
}

@end
