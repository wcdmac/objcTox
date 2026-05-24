#import <Realm/Realm.h>
#import "OCTGroupPeer.h"

@interface OCTGroup : RLMObject

@property NSInteger groupNumber;
@property NSData *chatId;
@property NSString *name;
@property NSString *topic;
@property NSInteger privacyState;
@property NSInteger selfRole;
@property NSInteger peerCount;
@property RLMArray<OCTGroupPeer> *peers;
@property NSTimeInterval lastMessageDateInterval;
@property NSString *uniqueIdentifier;

@end