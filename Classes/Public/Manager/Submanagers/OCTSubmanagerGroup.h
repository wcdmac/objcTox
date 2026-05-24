// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTGroupConstants.h"
#import "OCTToxConstants.h"

@protocol OCTSubmanagerGroupDelegate;
@protocol OCTSubmanagerProtocol;

extern NSString *const OCTSubmanagerGroupErrorDomain;

@protocol OCTSubmanagerGroup <OCTSubmanagerProtocol>

@property (weak, nonatomic) id<OCTSubmanagerGroupDelegate> delegate;

- (OCTGroupNumber)createGroupWithName:(NSString *)name privacyState:(OCTGroupPrivacyState)privacyState error:(NSError **)error;
- (OCTGroupNumber)joinGroupWithChatId:(NSData *)chatId name:(NSString *)name password:(NSString *)password error:(NSError **)error;
- (BOOL)inviteFriend:(OCTFriendNumber)friendNumber toGroup:(OCTGroupNumber)groupNumber error:(NSError **)error;
- (OCTGroupNumber)acceptInviteWithData:(NSData *)inviteData name:(NSString *)name password:(NSString *)password error:(NSError **)error;
- (uint32_t)sendMessage:(NSData *)message toGroup:(OCTGroupNumber)groupNumber type:(OCTToxMessageType)type error:(NSError **)error;
- (BOOL)sendCustomPacket:(NSData *)packet toGroup:(OCTGroupNumber)groupNumber lossless:(BOOL)lossless error:(NSError **)error;
- (BOOL)leaveGroup:(OCTGroupNumber)groupNumber withMessage:(NSString *)message error:(NSError **)error;
- (BOOL)setTopic:(NSString *)topic forGroup:(OCTGroupNumber)groupNumber error:(NSError **)error;
- (BOOL)kickPeer:(OCTGroupPeerNumber)peerNumber fromGroup:(OCTGroupNumber)groupNumber error:(NSError **)error;
- (BOOL)setRole:(OCTGroupRole)role forPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber error:(NSError **)error;
- (NSData *)getChatIdForGroup:(OCTGroupNumber)groupNumber error:(NSError **)error;
- (uint32_t)getGroupNumberGroups;

@end