// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import "OCTSubmanagerGroupImpl.h"
#import <objcTox/OCTSubmanagerGroupDelegate.h>
#import <objcTox/OCTGroupConstants.h>


#define TOX_GROUP_CHAT_ID_SIZE 32

typedef uint32_t (*tox_group_new_func)(void *, int, const uint8_t *, uint16_t, int *);
typedef uint32_t (*tox_group_join_func)(void *, const uint8_t *, const uint8_t *, uint16_t, const uint8_t *, uint16_t, int *);
typedef bool (*tox_group_invite_friend_func)(void *, uint32_t, uint32_t, int *);
typedef uint32_t (*tox_group_invite_accept_func)(void *, const uint8_t *, size_t, const uint8_t *, uint16_t, const uint8_t *, uint16_t, int *);
typedef uint32_t (*tox_group_send_message_func)(void *, uint32_t, int, const uint8_t *, size_t, int *);
typedef bool (*tox_group_send_custom_packet_func)(void *, uint32_t, bool, const uint8_t *, size_t, int *);
typedef bool (*tox_group_leave_func)(void *, uint32_t, const uint8_t *, uint16_t, int *);
typedef bool (*tox_group_set_topic_func)(void *, uint32_t, const uint8_t *, uint16_t, int *);
typedef bool (*tox_group_kick_peer_func)(void *, uint32_t, uint32_t, int *);
typedef bool (*tox_group_set_role_func)(void *, uint32_t, uint32_t, int, int *);
typedef bool (*tox_group_get_chat_id_func)(void *, uint32_t, uint8_t *, int *);
typedef uint32_t (*tox_group_get_number_groups_func)(const void *);

typedef void (*tox_callback_group_invite_func)(void *, void (*)(void *, uint32_t, const uint8_t *, size_t, const uint8_t *, size_t, void *), void *);
typedef void (*tox_callback_group_message_func)(void *, void (*)(void *, uint32_t, uint32_t, int, const uint8_t *, size_t, uint32_t, void *), void *);
typedef void (*tox_callback_group_private_message_func)(void *, void (*)(void *, uint32_t, uint32_t, int, const uint8_t *, size_t, void *), void *);
typedef void (*tox_callback_group_custom_packet_func)(void *, void (*)(void *, uint32_t, uint32_t, const uint8_t *, size_t, void *), void *);
typedef void (*tox_callback_group_peer_join_func)(void *, void (*)(void *, uint32_t, uint32_t, void *), void *);
typedef void (*tox_callback_group_peer_exit_func)(void *, void (*)(void *, uint32_t, uint32_t, int, const uint8_t *, size_t, const uint8_t *, size_t, void *), void *);
typedef void (*tox_callback_group_topic_func)(void *, void (*)(void *, uint32_t, uint32_t, const uint8_t *, size_t, void *), void *);
typedef void (*tox_callback_group_self_join_func)(void *, void (*)(void *, uint32_t, void *), void *);
typedef void (*tox_callback_group_join_reject_func)(void *, void (*)(void *, uint32_t, int, void *), void *);
typedef void (*tox_callback_group_peer_name_func)(void *, void (*)(void *, uint32_t, uint32_t, const uint8_t *, size_t, void *), void *);

static void *libHandle = NULL;

static void *sym(const char *name) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        libHandle = dlopen(NULL, RTLD_LAZY);
    });
    return dlsym(libHandle, name);
}

static void groupInviteCallback(void *tox, uint32_t friend_number, const uint8_t *invite_data, size_t length, const uint8_t *group_name, size_t group_name_length, void *user_data);
static void groupMessageCallback(void *tox, uint32_t group_number, uint32_t peer_number, int type, const uint8_t *message, size_t length, uint32_t message_id, void *user_data);
static void groupPrivateMessageCallback(void *tox, uint32_t group_number, uint32_t peer_number, int type, const uint8_t *message, size_t length, void *user_data);
static void groupCustomPacketCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *data, size_t length, void *user_data);
static void groupPeerJoinCallback(void *tox, uint32_t group_number, uint32_t peer_number, void *user_data);
static void groupPeerExitCallback(void *tox, uint32_t group_number, uint32_t peer_number, int exit_type, const uint8_t *name, size_t name_length, const uint8_t *part_message, size_t part_message_length, void *user_data);
static void groupTopicCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *topic, size_t length, void *user_data);
static void groupSelfJoinCallback(void *tox, uint32_t group_number, void *user_data);
static void groupJoinRejectedCallback(void *tox, uint32_t group_number, int reject_type, void *user_data);
static void groupPeerNameCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *name, size_t length, void *user_data);

NSString *const OCTSubmanagerGroupErrorDomain = @"OCTSubmanagerGroupErrorDomain";

@implementation OCTSubmanagerGroupImpl

- (instancetype)initWithToxPointer:(void *)toxPointer {
    self = [super init];
    if (self) {
        _toxPointer = toxPointer;
        [self registerCallbacks];
    }
    return self;
}

- (void)registerCallbacks {
    void *tox = self.toxPointer;
    if (!tox) return;

    tox_callback_group_invite_func cbInvite = (tox_callback_group_invite_func)sym("tox_callback_group_invite");
    if (cbInvite) cbInvite(tox, groupInviteCallback, (__bridge void *)self);

    tox_callback_group_message_func cbMessage = (tox_callback_group_message_func)sym("tox_callback_group_message");
    if (cbMessage) cbMessage(tox, groupMessageCallback, (__bridge void *)self);

    tox_callback_group_private_message_func cbPrivate = (tox_callback_group_private_message_func)sym("tox_callback_group_private_message");
    if (cbPrivate) cbPrivate(tox, groupPrivateMessageCallback, (__bridge void *)self);

    tox_callback_group_custom_packet_func cbCustom = (tox_callback_group_custom_packet_func)sym("tox_callback_group_custom_packet");
    if (cbCustom) cbCustom(tox, groupCustomPacketCallback, (__bridge void *)self);

    tox_callback_group_peer_join_func cbPeerJoin = (tox_callback_group_peer_join_func)sym("tox_callback_group_peer_join");
    if (cbPeerJoin) cbPeerJoin(tox, groupPeerJoinCallback, (__bridge void *)self);

    tox_callback_group_peer_exit_func cbPeerExit = (tox_callback_group_peer_exit_func)sym("tox_callback_group_peer_exit");
    if (cbPeerExit) cbPeerExit(tox, groupPeerExitCallback, (__bridge void *)self);

    tox_callback_group_topic_func cbTopic = (tox_callback_group_topic_func)sym("tox_callback_group_topic");
    if (cbTopic) cbTopic(tox, groupTopicCallback, (__bridge void *)self);

    tox_callback_group_self_join_func cbSelfJoin = (tox_callback_group_self_join_func)sym("tox_callback_group_self_join");
    if (cbSelfJoin) cbSelfJoin(tox, groupSelfJoinCallback, (__bridge void *)self);

    tox_callback_group_join_reject_func cbReject = (tox_callback_group_join_reject_func)sym("tox_callback_group_join_rejected");
    if (cbReject) cbReject(tox, groupJoinRejectedCallback, (__bridge void *)self);

    tox_callback_group_peer_name_func cbName = (tox_callback_group_peer_name_func)sym("tox_callback_group_peer_name");
    if (cbName) cbName(tox, groupPeerNameCallback, (__bridge void *)self);
}

- (OCTGroupNumber)createGroupWithName:(NSString *)name privacyState:(OCTGroupPrivacyState)privacyState error:(NSError **)error {
    tox_group_new_func func = (tox_group_new_func)sym("tox_group_new");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:nil]; return UINT32_MAX; }

    int err = 0;
    const char *nameC = name ? [name UTF8String] : "";
    uint16_t nameLen = (uint16_t)strlen(nameC);
    uint32_t result = func(self.toxPointer, (int)privacyState, (const uint8_t *)nameC, nameLen, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:nil];
    }
    return result;
}

- (OCTGroupNumber)joinGroupWithChatId:(NSData *)chatId name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    tox_group_join_func func = (tox_group_join_func)sym("tox_group_join");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil]; return UINT32_MAX; }

    int err = 0;
    const char *nameC = name ? [name UTF8String] : "";
    uint16_t nameLen = (uint16_t)strlen(nameC);
    const char *passC = password ? [password UTF8String] : "";
    uint16_t passLen = (uint16_t)strlen(passC);

    uint32_t result = func(self.toxPointer, [chatId bytes], (const uint8_t *)nameC, nameLen, (const uint8_t *)passC, passLen, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil];
    }
    return result;
}

- (BOOL)inviteFriend:(OCTFriendNumber)friendNumber toGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    tox_group_invite_friend_func func = (tox_group_invite_friend_func)sym("tox_group_invite_friend");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:nil]; return NO; }

    int err = 0;
    bool result = func(self.toxPointer, (uint32_t)friendNumber, groupNumber, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:nil];
    }
    return result;
}

- (OCTGroupNumber)acceptInviteWithData:(NSData *)inviteData name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    tox_group_invite_accept_func func = (tox_group_invite_accept_func)sym("tox_group_invite_accept");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil]; return UINT32_MAX; }

    int err = 0;
    const char *nameC = name ? [name UTF8String] : "";
    uint16_t nameLen = (uint16_t)strlen(nameC);
    const char *passC = password ? [password UTF8String] : "";
    uint16_t passLen = (uint16_t)strlen(passC);

    uint32_t result = func(self.toxPointer, [inviteData bytes], [inviteData length], (const uint8_t *)nameC, nameLen, (const uint8_t *)passC, passLen, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil];
    }
    return result;
}

- (uint32_t)sendMessage:(NSData *)message toGroup:(OCTGroupNumber)groupNumber type:(OCTToxMessageType)type error:(NSError **)error {
    tox_group_send_message_func func = (tox_group_send_message_func)sym("tox_group_send_message");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendMessage userInfo:nil]; return 0; }

    int err = 0;
    uint32_t result = func(self.toxPointer, groupNumber, (int)type, [message bytes], [message length], &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendMessage userInfo:nil];
    }
    return result;
}

- (BOOL)sendCustomPacket:(NSData *)packet toGroup:(OCTGroupNumber)groupNumber lossless:(BOOL)lossless error:(NSError **)error {
    tox_group_send_custom_packet_func func = (tox_group_send_custom_packet_func)sym("tox_group_send_custom_packet");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendCustomPacket userInfo:nil]; return NO; }

    int err = 0;
    bool result = func(self.toxPointer, groupNumber, lossless, [packet bytes], [packet length], &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendCustomPacket userInfo:nil];
    }
    return result;
}

- (BOOL)leaveGroup:(OCTGroupNumber)groupNumber withMessage:(NSString *)message error:(NSError **)error {
    tox_group_leave_func func = (tox_group_leave_func)sym("tox_group_leave");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorLeave userInfo:nil]; return NO; }

    int err = 0;
    const char *msgC = message ? [message UTF8String] : "";
    uint16_t msgLen = (uint16_t)strlen(msgC);
    bool result = func(self.toxPointer, groupNumber, (const uint8_t *)msgC, msgLen, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorLeave userInfo:nil];
    }
    return result;
}

- (BOOL)setTopic:(NSString *)topic forGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    tox_group_set_topic_func func = (tox_group_set_topic_func)sym("tox_group_set_topic");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetTopic userInfo:nil]; return NO; }

    int err = 0;
    const char *topicC = topic ? [topic UTF8String] : "";
    uint16_t topicLen = (uint16_t)strlen(topicC);
    bool result = func(self.toxPointer, groupNumber, (const uint8_t *)topicC, topicLen, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetTopic userInfo:nil];
    }
    return result;
}

- (BOOL)kickPeer:(OCTGroupPeerNumber)peerNumber fromGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    tox_group_kick_peer_func func = (tox_group_kick_peer_func)sym("tox_group_kick_peer");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorKickPeer userInfo:nil]; return NO; }

    int err = 0;
    bool result = func(self.toxPointer, groupNumber, peerNumber, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorKickPeer userInfo:nil];
    }
    return result;
}

- (BOOL)setRole:(OCTGroupRole)role forPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    tox_group_set_role_func func = (tox_group_set_role_func)sym("tox_group_set_role");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetRole userInfo:nil]; return NO; }

    int err = 0;
    bool result = func(self.toxPointer, groupNumber, peerNumber, (int)role, &err);

    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetRole userInfo:nil];
    }
    return result;
}

- (NSData *)getChatIdForGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    tox_group_get_chat_id_func func = (tox_group_get_chat_id_func)sym("tox_group_get_chat_id");
    if (!func) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGetChatId userInfo:nil]; return nil; }

    int err = 0;
    uint8_t chatId[TOX_GROUP_CHAT_ID_SIZE];
    bool result = func(self.toxPointer, groupNumber, chatId, &err);

    if (!result || err != 0) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGetChatId userInfo:nil];
        return nil;
    }

    return [NSData dataWithBytes:chatId length:TOX_GROUP_CHAT_ID_SIZE];
}

- (uint32_t)getGroupNumberGroups {
    tox_group_get_number_groups_func func = (tox_group_get_number_groups_func)sym("tox_group_get_number_groups");
    if (!func) return 0;
    return func(self.toxPointer);
}

@end

static void dispatchToMain(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static void groupInviteCallback(void *tox, uint32_t friend_number, const uint8_t *invite_data, size_t length, const uint8_t *group_name, size_t group_name_length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSData *inviteData = [NSData dataWithBytes:invite_data length:length];
    NSString *groupName = [[NSString alloc] initWithBytes:group_name length:group_name_length encoding:NSUTF8StringEncoding];
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager inviteReceived:inviteData fromFriend:(OCTFriendNumber)friend_number groupName:groupName]; });
}

static void groupMessageCallback(void *tox, uint32_t group_number, uint32_t peer_number, int type, const uint8_t *message, size_t length, uint32_t message_id, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSData *messageData = [NSData dataWithBytes:message length:length];
    OCTToxMessageType msgType = (type == 1) ? OCTToxMessageTypeAction : OCTToxMessageTypeNormal;
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager messageReceived:messageData fromPeer:(OCTGroupPeerNumber)peer_number inGroup:(OCTGroupNumber)group_number type:msgType messageId:message_id]; });
}

static void groupPrivateMessageCallback(void *tox, uint32_t group_number, uint32_t peer_number, int type, const uint8_t *message, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSData *messageData = [NSData dataWithBytes:message length:length];
    OCTToxMessageType msgType = (type == 1) ? OCTToxMessageTypeAction : OCTToxMessageTypeNormal;
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager privateMessageReceived:messageData fromPeer:(OCTGroupPeerNumber)peer_number inGroup:(OCTGroupNumber)group_number type:msgType]; });
}

static void groupCustomPacketCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *data, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSData *packetData = [NSData dataWithBytes:data length:length];
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager customPacketReceived:packetData fromPeer:(OCTGroupPeerNumber)peer_number inGroup:(OCTGroupNumber)group_number]; });
}

static void groupPeerJoinCallback(void *tox, uint32_t group_number, uint32_t peer_number, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager peerJoined:(OCTGroupPeerNumber)peer_number inGroup:(OCTGroupNumber)group_number]; });
}

static void groupPeerExitCallback(void *tox, uint32_t group_number, uint32_t peer_number, int exit_type, const uint8_t *name, size_t name_length, const uint8_t *part_message, size_t part_message_length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSString *nameStr = [[NSString alloc] initWithBytes:name length:name_length encoding:NSUTF8StringEncoding];
    NSString *partMsg = [[NSString alloc] initWithBytes:part_message length:part_message_length encoding:NSUTF8StringEncoding];
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager peerLeft:(OCTGroupPeerNumber)peer_number inGroup:(OCTGroupNumber)group_number exitType:(OCTGroupExitType)exit_type name:nameStr partMessage:partMsg]; });
}

static void groupTopicCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *topic, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSString *topicStr = [[NSString alloc] initWithBytes:topic length:length encoding:NSUTF8StringEncoding];
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager topicChanged:topicStr inGroup:(OCTGroupNumber)group_number byPeer:(OCTGroupPeerNumber)peer_number]; });
}

static void groupSelfJoinCallback(void *tox, uint32_t group_number, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager selfJoinedGroup:(OCTGroupNumber)group_number]; });
}

static void groupJoinRejectedCallback(void *tox, uint32_t group_number, int reject_type, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager joinRejected:(OCTGroupRejectType)reject_type inGroup:(OCTGroupNumber)group_number]; });
}

static void groupPeerNameCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *name, size_t length, void *user_data) {
    OCTSubmanagerGroupImpl *submanager = (__bridge OCTSubmanagerGroupImpl *)user_data;
    NSString *nameStr = [[NSString alloc] initWithBytes:name length:length encoding:NSUTF8StringEncoding];
    dispatchToMain(^{ [submanager.delegate groupSubmanager:submanager peerNameChanged:(OCTGroupPeerNumber)peer_number inGroup:(OCTGroupNumber)group_number newName:nameStr]; });
}