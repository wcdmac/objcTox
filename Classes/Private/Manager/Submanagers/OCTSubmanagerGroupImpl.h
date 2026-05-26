#import <Foundation/Foundation.h>
#import <objcTox/OCTSubmanagerGroup.h>

@class OCTTox;

@interface OCTSubmanagerGroupImpl : NSObject <OCTSubmanagerGroup>

@property (nonatomic, weak, readonly) OCTTox *tox;

- (instancetype)initWithTox:(OCTTox *)tox delegate:(id<OCTSubmanagerGroupDelegate>)delegate;

@end