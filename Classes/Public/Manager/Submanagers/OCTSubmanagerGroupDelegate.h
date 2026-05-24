// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

iimport <Foundation/Foundation.h>
iimport "OCTGroupConstants.h"

@protocol OCTSubmanagerGroup;

@protocol OCTSubmanagerGroupDelegate <NSObject>

- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager inviteReceived:(NSData *)inviteData fromFriend:(OCTFriendNumber)friendNumber groupName:(NSString *)groupName;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager messageReceived:(NSData *)message fromPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber type:(OCTToxMessageType)type messageId:(uint32_t)messageId;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager privateMessageReceived:(NSData *)message fromPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber type:(OCTToxMessageType)type;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager customPacketReceived:(NSData *)packet fromPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager peerJoined:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager peerLeft:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber exitType:(OCTGroupExitType)exitType name:(NSString *)name partMessage:(NSString *)partMessage;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager topicChanged:(NSString *)topic inGroup:(OCTGroupNumber)groupNumber byPeer:(OCTGroupPeerNumber)peerNumber;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager selfJoinedGroup:(OCTGroupNumber)groupNumber;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager joinRejected:(OCTGroupRejectType)rejectType inGroup:(OCTGroupNumber)groupNumber;
- (void)groupSubmanager:(id<OCTSubmanagerGroup>)submanager peerNameChanged:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber newName:(NSString *)newName;

@end