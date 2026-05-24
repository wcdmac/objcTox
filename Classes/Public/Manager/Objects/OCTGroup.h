#import <objcTox/OCTObject.h>
#import <objcTox/OCTGroupPeer.h>

@interface OCTGroup : OCTObject

@property NSInteger groupNumber;
@property NSData *chatId;
@property NSString *name;
@property NSString *topic;
@property NSInteger privacyState;
@property NSInteger selfRole;
@property NSInteger peerCount;
@property RLMArray<OCTGroupPeer> *peers;
@property NSTimeInterval lastMessageDateInterval;

@end