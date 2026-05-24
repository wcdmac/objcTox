#import "OpusBridge.h"
#import <dlfcn.h>

typedef int (*opus_encoder_create_func)(int, int, int, int *);
typedef void (*opus_encoder_destroy_func)(void *);
typedef int (*opus_encode_func)(void *, const int16_t *, int, unsigned char *, int);
typedef int (*opus_decoder_create_func)(int, int, int *);
typedef void (*opus_decoder_destroy_func)(void *);
typedef int (*opus_decode_func)(void *, const unsigned char *, int, int16_t *, int, int);

static void *sym(const char *name) {
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen(NULL, RTLD_LAZY);
    });
    return dlsym(handle, name);
}

@interface OpusBridge ()
@property (nonatomic, assign) void *encoder;
@property (nonatomic, assign) void *decoder;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channels;
@end

@implementation OpusBridge

- (instancetype)initWithSampleRate:(int)sampleRate channels:(int)channels {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        _channels = channels;
        [self createEncoder];
        [self createDecoder];
    }
    return self;
}

- (void)createEncoder {
    opus_encoder_create_func func = (opus_encoder_create_func)sym("opus_encoder_create");
    if (!func) return;
    int error = 0;
    _encoder = (void *)func(_sampleRate, _channels, 2048, &error);
    if (error != 0) _encoder = NULL;
}

- (void)createDecoder {
    opus_decoder_create_func func = (opus_decoder_create_func)sym("opus_decoder_create");
    if (!func) return;
    int error = 0;
    _decoder = (void *)func(_sampleRate, _channels, &error);
    if (error != 0) _decoder = NULL;
}

- (NSData *)encodePCMBuffer:(const int16_t *)buffer frameCount:(int)frameCount {
    if (!self.encoder || !buffer) return nil;
    opus_encode_func func = (opus_encode_func)sym("opus_encode");
    if (!func) return nil;
    
    int maxDataBytes = 4000;
    uint8_t *encodedData = (uint8_t *)malloc(maxDataBytes);
    int encodedLength = func(self.encoder, buffer, frameCount, encodedData, maxDataBytes);
    
    if (encodedLength <= 0) {
        free(encodedData);
        return nil;
    }
    
    NSData *result = [NSData dataWithBytes:encodedData length:encodedLength];
    free(encodedData);
    return result;
}

- (int)decodeData:(NSData *)encodedData toPCMBuffer:(int16_t *)buffer frameCount:(int)frameCount {
    if (!self.decoder || !encodedData || !buffer) return -1;
    opus_decode_func func = (opus_decode_func)sym("opus_decode");
    if (!func) return -1;
    
    int samples = func(self.decoder, [encodedData bytes], (int)[encodedData length], buffer, frameCount, 0);
    return samples;
}

- (void)destroyEncoder {
    if (self.encoder) {
        opus_encoder_destroy_func func = (opus_encoder_destroy_func)sym("opus_encoder_destroy");
        if (func) func(self.encoder);
        _encoder = NULL;
    }
}

- (void)destroyDecoder {
    if (self.decoder) {
        opus_decoder_destroy_func func = (opus_decoder_destroy_func)sym("opus_decoder_destroy");
        if (func) func(self.decoder);
        _decoder = NULL;
    }
}

- (void)dealloc {
    [self destroyEncoder];
    [self destroyDecoder];
}

@end