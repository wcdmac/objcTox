#import <objcTox/OCTObject.h>

@class OCTGroup;

RLM_ARRAY_TYPE(OCTGroupPeer)

@interface OCTGroupPeer : OCTObject

@property NSInteger peerNumber;
@property NSString *publicKey;
@property NSString *name;
@property NSInteger role;
@property NSInteger connectionStatus;
@property OCTGroup *group;

@end