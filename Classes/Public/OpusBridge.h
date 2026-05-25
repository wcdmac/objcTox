#import <Foundation/Foundation.h>

@interface OpusBridge : NSObject

- (instancetype)initWithSampleRate:(int)sampleRate channels:(int)channels;

- (NSData *)encodePCMBuffer:(const int16_t *)buffer frameCount:(int)frameCount;
- (int)decodeData:(NSData *)encodedData toPCMBuffer:(int16_t *)buffer frameCount:(int)frameCount NS_SWIFT_NAME(decodeData(_:toPCMBuffer:frameCount:));

- (void)destroyEncoder;
- (void)destroyDecoder;

@end