// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTSubmanagerGroupImpl.h"
#import "OCTTox+Private.h"
#import <objcTox/OCTSubmanagerGroupDelegate.h>
#import <objcTox/OCTGroupConstants.h>
#import <toxcore/tox.h>

static OCTSubmanagerGroupImpl *sSharedManager = nil;

NSString *const OCTSubmanagerGroupErrorDomain = @"OCTSubmanagerGroupErrorDomain";

@implementation OCTSubmanagerGroupImpl

+ (instancetype)sharedManager {
    return sSharedManager;
}

- (instancetype)initWithTox:(OCTTox *)tox {
    self = [super init];
    if (self) {
        _tox = tox;
        sSharedManager = self;
        [self registerCallbacks];
    }
    return self;
}

- (void)registerCallbacks {
    Tox *tox = self.tox.tox;
    if (!tox) {
        NSLog(@"OCTSubmanagerGroupImpl: tox is nil, cannot register callbacks");
        return;
    }

    tox_callback_group_invite(tox, groupInviteCallback);
    tox_callback_group_message(tox, groupMessageCallback);
    tox_callback_group_private_message(tox, groupPrivateMessageCallback);
    tox_callback_group_custom_packet(tox, groupCustomPacketCallback);
    tox_callback_group_peer_join(tox, groupPeerJoinCallback);
    tox_callback_group_peer_exit(tox, groupPeerExitCallback);
    tox_callback_group_topic(tox, groupTopicCallback);
    tox_callback_group_self_join(tox, groupSelfJoinCallback);
    tox_callback_group_join_fail(tox, groupJoinFailCallback);
    tox_callback_group_peer_name(tox, groupPeerNameCallback);

    NSLog(@"OCTSubmanagerGroupImpl: all Group v2 callbacks registered");
}

- (OCTGroupNumber)createGroupWithName:(NSString *)name privacyState:(OCTGroupPrivacyState)privacyState error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return UINT32_MAX;
    }

    Tox_Err_Group_New err = TOX_ERR_GROUP_NEW_OK;
    const char *nameC = name ? [name UTF8String] : "";
    size_t nameLen = strlen(nameC);

    const char *selfNameC = "";
    size_t selfNameLen = 0;

    uint32_t groupNumber = tox_group_new(tox, (Tox_Group_Privacy_State)privacyState,
                                          (const uint8_t *)nameC, nameLen,
                                          (const uint8_t *)selfNameC, selfNameLen,
                                          &err);

    if (err != TOX_ERR_GROUP_NEW_OK) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_new failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"tox_group_new error: %d", err]}];
        return UINT32_MAX;
    }

    NSLog(@"OCTSubmanagerGroupImpl: created group %u", groupNumber);
    return groupNumber;
}

- (OCTGroupNumber)joinGroupWithChatId:(NSData *)chatId name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return UINT32_MAX;
    }

    if (!chatId || [chatId length] != tox_group_chat_id_size()) {
        NSLog(@"OCTSubmanagerGroupImpl: invalid chat ID length %lu, expected %u",
              (unsigned long)[chatId length], tox_group_chat_id_size());
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:@{NSLocalizedDescriptionKey: @"Invalid chat ID"}];
        return UINT32_MAX;
    }

    Tox_Err_Group_Join err = TOX_ERR_GROUP_JOIN_OK;
    const char *nameC = name ? [name UTF8String] : "";
    size_t nameLen = strlen(nameC);
    const char *passC = password ? [password UTF8String] : "";
    size_t passLen = strlen(passC);

    uint32_t groupNumber = tox_group_join(tox,
                                           (const uint8_t *)[chatId bytes],
                                           (const uint8_t *)nameC, nameLen,
                                           (const uint8_t *)passC, passLen,
                                           &err);

    if (err != TOX_ERR_GROUP_JOIN_OK) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_join failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"tox_group_join error: %d", err]}];
        return UINT32_MAX;
    }

    NSLog(@"OCTSubmanagerGroupImpl: joined group %u", groupNumber);
    return groupNumber;
}

- (BOOL)inviteFriend:(OCTFriendNumber)friendNumber toGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return NO;
    }

    Tox_Err_Group_Invite_Friend err = TOX_ERR_GROUP_INVITE_FRIEND_OK;
    bool result = tox_group_invite_friend(tox, groupNumber, (uint32_t)friendNumber, &err);

    if (err != TOX_ERR_GROUP_INVITE_FRIEND_OK) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_invite_friend failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"tox_group_invite_friend error: %d", err]}];
        return NO;
    }

    return result;
}

- (OCTGroupNumber)acceptInviteWithData:(NSData *)inviteData name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return UINT32_MAX;
    }

    if (!inviteData) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:@{NSLocalizedDescriptionKey: @"Invite data is nil"}];
        return UINT32_MAX;
    }

    NSNumber *friendNumberObj = [self.inviteFriendNumbers objectForKey:inviteData];
    uint32_t friendNumber = friendNumberObj ? [friendNumberObj unsignedIntValue] : 0;

    Tox_Err_Group_Invite_Accept err = TOX_ERR_GROUP_INVITE_ACCEPT_OK;
    const char *nameC = name ? [name UTF8String] : "";
    size_t nameLen = strlen(nameC);
    const char *passC = password ? [password UTF8String] : "";
    size_t passLen = strlen(passC);

    uint32_t groupNumber = tox_group_invite_accept(tox,
                                                     friendNumber,
                                                     (const uint8_t *)[inviteData bytes], [inviteData length],
                                                     (const uint8_t *)nameC, nameLen,
                                                     (const uint8_t *)passC, passLen,
                                                     &err);

    if (err != TOX_ERR_GROUP_INVITE_ACCEPT_OK) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_invite_accept failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"tox_group_invite_accept error: %d", err]}];
        return UINT32_MAX;
    }

    [self.inviteFriendNumbers removeObjectForKey:inviteData];
    NSLog(@"OCTSubmanagerGroupImpl: accepted invite, group %u", groupNumber);
    return groupNumber;
}

- (uint32_t)sendMessage:(NSData *)message toGroup:(OCTGroupNumber)groupNumber type:(OCTToxMessageType)type error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendMessage userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return 0;
    }

    Tox_Err_Group_Send_Message err = TOX_ERR_GROUP_SEND_MESSAGE_OK;
    uint32_t messageId = 0;

    bool result = tox_group_send_message(tox, groupNumber, (Tox_Message_Type)type,
                                          (const uint8_t *)[message bytes], [message length],
                                          &messageId, &err);

    if (err != TOX_ERR_GROUP_SEND_MESSAGE_OK || !result) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_send_message failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendMessage userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"tox_group_send_message error: %d", err]}];
        return 0;
    }

    return messageId;
}

- (BOOL)sendCustomPacket:(NSData *)packet toGroup:(OCTGroupNumber)groupNumber lossless:(BOOL)lossless error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendCustomPacket userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return NO;
    }

    Tox_Err_Group_Send_Custom_Packet err = TOX_ERR_GROUP_SEND_CUSTOM_PACKET_OK;
    bool result = tox_group_send_custom_packet(tox, groupNumber, lossless,
                                                (const uint8_t *)[packet bytes], [packet length],
                                                &err);

    if (err != TOX_ERR_GROUP_SEND_CUSTOM_PACKET_OK || !result) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_send_custom_packet failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendCustomPacket userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"error: %d", err]}];
        return NO;
    }

    return YES;
}

- (BOOL)leaveGroup:(OCTGroupNumber)groupNumber withMessage:(NSString *)message error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorLeave userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return NO;
    }

    Tox_Err_Group_Leave err = TOX_ERR_GROUP_LEAVE_OK;
    const char *msgC = message ? [message UTF8String] : "";
    size_t msgLen = strlen(msgC);

    bool result = tox_group_leave(tox, groupNumber, (const uint8_t *)msgC, msgLen, &err);

    if (err != TOX_ERR_GROUP_LEAVE_OK || !result) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_leave failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorLeave userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"error: %d", err]}];
        return NO;
    }

    return YES;
}

- (BOOL)setTopic:(NSString *)topic forGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetTopic userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return NO;
    }

    Tox_Err_Group_Topic_Set err = TOX_ERR_GROUP_TOPIC_SET_OK;
    const char *topicC = topic ? [topic UTF8String] : "";
    size_t topicLen = strlen(topicC);

    bool result = tox_group_set_topic(tox, groupNumber, (const uint8_t *)topicC, topicLen, &err);

    if (err != TOX_ERR_GROUP_TOPIC_SET_OK || !result) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_set_topic failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetTopic userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"error: %d", err]}];
        return NO;
    }

    return YES;
}

- (BOOL)kickPeer:(OCTGroupPeerNumber)peerNumber fromGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorKickPeer userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return NO;
    }

    Tox_Err_Group_Mod_Kick_Peer err = TOX_ERR_GROUP_MOD_KICK_PEER_OK;
    bool result = tox_group_mod_kick_peer(tox, groupNumber, peerNumber, &err);

    if (err != TOX_ERR_GROUP_MOD_KICK_PEER_OK || !result) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_mod_kick_peer failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorKickPeer userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"error: %d", err]}];
        return NO;
    }

    return YES;
}

- (BOOL)setRole:(OCTGroupRole)role forPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetRole userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return NO;
    }

    Tox_Err_Group_Mod_Set_Role err = TOX_ERR_GROUP_MOD_SET_ROLE_OK;
    bool result = tox_group_mod_set_role(tox, groupNumber, peerNumber, (Tox_Group_Role)role, &err);

    if (err != TOX_ERR_GROUP_MOD_SET_ROLE_OK || !result) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_mod_set_role failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetRole userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"error: %d", err]}];
        return NO;
    }

    return YES;
}

- (NSData *)getChatIdForGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = self.tox.tox;
    if (!tox) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGetChatId userInfo:@{NSLocalizedDescriptionKey: @"Tox instance is nil"}];
        return nil;
    }

    Tox_Err_Group_State_Queries err = TOX_ERR_GROUP_STATE_QUERIES_OK;
    uint8_t chatId[TOX_GROUP_CHAT_ID_SIZE];

    bool result = tox_group_get_chat_id(tox, groupNumber, chatId, &err);

    if (!result || err != TOX_ERR_GROUP_STATE_QUERIES_OK) {
        NSLog(@"OCTSubmanagerGroupImpl: tox_group_get_chat_id failed with error %d", err);
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGetChatId userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"error: %d", err]}];
        return nil;
    }

    return [NSData dataWithBytes:chatId length:TOX_GROUP_CHAT_ID_SIZE];
}

- (uint32_t)getGroupNumberGroups {
    Tox *tox = self.tox.tox;
    if (!tox) return 0;
    return tox_group_get_number_groups(tox);
}

@end

static void dispatchToMain(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static void groupInviteCallback(Tox *tox, uint32_t friend_number, const uint8_t *invite_data, size_t length, const uint8_t *group_name, size_t group_name_length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSData *inviteData = [NSData dataWithBytes:invite_data length:length];
    NSString *groupName = [[NSString alloc] initWithBytes:group_name length:group_name_length encoding:NSUTF8StringEncoding];

    if (!submanager.inviteFriendNumbers) {
        submanager.inviteFriendNumbers = [NSMutableDictionary dictionary];
    }
    [submanager.inviteFriendNumbers setObject:@(friend_number) forKey:inviteData];

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:inviteReceivedWithData:fromFriend:groupName:)]) {
            [submanager.delegate groupSubmanager:submanager inviteReceivedWithData:inviteData fromFriend:friend_number groupName:groupName];
        }
    });
}

static void groupMessageCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, Tox_Message_Type type, const uint8_t *message, size_t length, uint32_t message_id, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSData *messageData = [NSData dataWithBytes:message length:length];

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:messageReceived:fromPeer:inGroup:type:messageId:)]) {
            [submanager.delegate groupSubmanager:submanager messageReceived:messageData fromPeer:peer_id inGroup:group_number type:type messageId:message_id];
        }
    });
}

static void groupPrivateMessageCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, Tox_Message_Type type, const uint8_t *message, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSData *messageData = [NSData dataWithBytes:message length:length];

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:privateMessageReceived:fromPeer:inGroup:type:)]) {
            [submanager.delegate groupSubmanager:submanager privateMessageReceived:messageData fromPeer:peer_id inGroup:group_number type:type];
        }
    });
}

static void groupCustomPacketCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, const uint8_t *data, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSData *packetData = [NSData dataWithBytes:data length:length];

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:customPacketReceived:fromPeer:inGroup:)]) {
            [submanager.delegate groupSubmanager:submanager customPacketReceived:packetData fromPeer:peer_id inGroup:group_number];
        }
    });
}

static void groupPeerJoinCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:peerJoined:inGroup:)]) {
            [submanager.delegate groupSubmanager:submanager peerJoined:peer_id inGroup:group_number];
        }
    });
}

static void groupPeerExitCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, Tox_Group_Exit_Type exit_type, const uint8_t *name, size_t name_length, const uint8_t *part_message, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSString *peerName = [[NSString alloc] initWithBytes:name length:name_length encoding:NSUTF8StringEncoding];
    NSString *partMsg = length > 0 ? [[NSString alloc] initWithBytes:part_message length:length encoding:NSUTF8StringEncoding] : nil;

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:peerExited:inGroup:exitType:name:partMessage:)]) {
            [submanager.delegate groupSubmanager:submanager peerExited:peer_id inGroup:group_number exitType:exit_type name:peerName partMessage:partMsg];
        }
    });
}

static void groupTopicCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, const uint8_t *topic, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSString *topicStr = [[NSString alloc] initWithBytes:topic length:length encoding:NSUTF8StringEncoding];

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:topicChanged:inGroup:byPeer:)]) {
            [submanager.delegate groupSubmanager:submanager topicChanged:topicStr inGroup:group_number byPeer:peer_id];
        }
    });
}

static void groupSelfJoinCallback(Tox *tox, uint32_t group_number, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:selfJoinedGroup:)]) {
            [submanager.delegate groupSubmanager:submanager selfJoinedGroup:group_number];
        }
    });
}

static void groupJoinFailCallback(Tox *tox, uint32_t group_number, Tox_Group_Join_Fail fail_type, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:joinFailedForGroup:failType:)]) {
            [submanager.delegate groupSubmanager:submanager joinFailedForGroup:group_number failType:fail_type];
        }
    });
}

static void groupPeerNameCallback(Tox *tox, uint32_t group_number, uint32_t peer_id, const uint8_t *name, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = [OCTSubmanagerGroupImpl sharedManager];
    if (!submanager) return;

    NSString *nameStr = [[NSString alloc] initWithBytes:name length:length encoding:NSUTF8StringEncoding];

    dispatchToMain(^{
        if ([submanager.delegate respondsToSelector:@selector(groupSubmanager:peerNameChanged:inGroup:forPeer:)]) {
            [submanager.delegate groupSubmanager:submanager peerNameChanged:nameStr inGroup:group_number forPeer:peer_id];
        }
    });
}
