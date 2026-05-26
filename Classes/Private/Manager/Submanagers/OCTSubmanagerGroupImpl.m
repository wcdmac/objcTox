// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTSubmanagerGroupImpl.h"
#import "OCTTox+Private.h"
#import <objcTox/OCTSubmanagerGroupDelegate.h>
#import <objcTox/OCTGroupConstants.h>

#define TOX_GROUP_CHAT_ID_SIZE 32

extern uint32_t tox_group_new(void *tox, int privacy, const uint8_t *name, size_t name_length, int *error);
extern uint32_t tox_group_join(void *tox, const uint8_t *chat_id, const uint8_t *name, size_t name_length, const uint8_t *password, size_t password_length, int *error);
extern bool tox_group_invite_friend(void *tox, uint32_t friend_number, uint32_t group_number, int *error);
extern uint32_t tox_group_invite_accept(void *tox, uint32_t friend_number, const uint8_t *invite_data, size_t length, const uint8_t *name, size_t name_length, const uint8_t *password, size_t password_length, int *error);
extern uint32_t tox_group_send_message(void *tox, uint32_t group_number, int type, const uint8_t *message, size_t length, int *error);
extern bool tox_group_send_custom_packet(void *tox, uint32_t group_number, bool lossless, const uint8_t *data, size_t length, int *error);
extern bool tox_group_leave(void *tox, uint32_t group_number, const uint8_t *part_message, size_t length, int *error);
extern bool tox_group_set_topic(void *tox, uint32_t group_number, const uint8_t *topic, size_t length, int *error);
extern bool tox_group_kick_peer(void *tox, uint32_t group_number, uint32_t peer_id, int *error);
extern bool tox_group_set_role(void *tox, uint32_t group_number, uint32_t peer_id, int role, int *error);
extern bool tox_group_get_chat_id(void *tox, uint32_t group_number, uint8_t *chat_id, int *error);
extern uint32_t tox_group_get_number_groups(const void *tox);

extern void tox_callback_group_invite(void *tox, void (*callback)(void *, uint32_t, const uint8_t *, size_t, const uint8_t *, size_t, void *), void *user_data);
extern void tox_callback_group_message(void *tox, void (*callback)(void *, uint32_t, uint32_t, int, const uint8_t *, size_t, uint32_t, void *), void *user_data);
extern void tox_callback_group_private_message(void *tox, void (*callback)(void *, uint32_t, uint32_t, int, const uint8_t *, size_t, void *), void *user_data);
extern void tox_callback_group_custom_packet(void *tox, void (*callback)(void *, uint32_t, uint32_t, const uint8_t *, size_t, void *), void *user_data);
extern void tox_callback_group_peer_join(void *tox, void (*callback)(void *, uint32_t, uint32_t, void *), void *user_data);
extern void tox_callback_group_peer_exit(void *tox, void (*callback)(void *, uint32_t, uint32_t, int, const uint8_t *, size_t, const uint8_t *, size_t, void *), void *user_data);
extern void tox_callback_group_topic(void *tox, void (*callback)(void *, uint32_t, uint32_t, const uint8_t *, size_t, void *), void *user_data);
extern void tox_callback_group_self_join(void *tox, void (*callback)(void *, uint32_t, void *), void *user_data);
extern void tox_callback_group_join_rejected(void *tox, void (*callback)(void *, uint32_t, int, void *), void *user_data);
extern void tox_callback_group_peer_name(void *tox, void (*callback)(void *, uint32_t, uint32_t, const uint8_t *, size_t, void *), void *user_data);

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

@interface OCTSubmanagerGroupImpl () {
    OCTTox *_tox;
    id<OCTSubmanagerGroupDelegate> _delegate;
    id _dataSource;
}
@end

@implementation OCTSubmanagerGroupImpl

- (instancetype)initWithTox:(OCTTox *)tox {
    self = [super init];
    if (self) {
        _tox = tox;
        if (_tox == nil || _tox.tox == NULL) {
            NSLog(@"OCTSubmanagerGroupImpl: tox is nil or tox.tox is NULL, group features disabled");
            return self;
        }
        [self registerCallbacks];
    }
    return self;
}

- (id<OCTSubmanagerGroupDelegate>)delegate {
    return _delegate;
}

- (void)setDelegate:(id<OCTSubmanagerGroupDelegate>)delegate {
    _delegate = delegate;
}

- (id)dataSource {
    return _dataSource;
}

- (void)setDataSource:(id)dataSource {
    _dataSource = dataSource;
}

- (void)registerCallbacks {
    void *tox = _tox.tox;
    if (!tox) return;

    tox_callback_group_invite(tox, groupInviteCallback, (__bridge void *)self);
    tox_callback_group_message(tox, groupMessageCallback, (__bridge void *)self);
    tox_callback_group_private_message(tox, groupPrivateMessageCallback, (__bridge void *)self);
    tox_callback_group_custom_packet(tox, groupCustomPacketCallback, (__bridge void *)self);
    tox_callback_group_peer_join(tox, groupPeerJoinCallback, (__bridge void *)self);
    tox_callback_group_peer_exit(tox, groupPeerExitCallback, (__bridge void *)self);
    tox_callback_group_topic(tox, groupTopicCallback, (__bridge void *)self);
    tox_callback_group_self_join(tox, groupSelfJoinCallback, (__bridge void *)self);
    tox_callback_group_join_rejected(tox, groupJoinRejectedCallback, (__bridge void *)self);
    tox_callback_group_peer_name(tox, groupPeerNameCallback, (__bridge void *)self);

    NSLog(@"OCTSubmanagerGroupImpl: all group callbacks registered");
}

- (OCTGroupNumber)createGroupWithName:(NSString *)name privacyState:(OCTGroupPrivacyState)privacyState error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:nil]; return UINT32_MAX; }
    int err = 0;
    const char *nameC = name ? [name UTF8String] : "";
    uint32_t result = tox_group_new(tox, (int)privacyState, (const uint8_t *)nameC, strlen(nameC), &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:nil];
    }
    NSLog(@"OCTSubmanagerGroupImpl: createGroupWithName result=%u err=%d", result, err);
    return result;
}

- (OCTGroupNumber)joinGroupWithChatId:(NSData *)chatId name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil]; return UINT32_MAX; }
    int err = 0;
    const char *nameC = name ? [name UTF8String] : "";
    const char *passC = password ? [password UTF8String] : "";
    uint32_t result = tox_group_join(tox, [chatId bytes], (const uint8_t *)nameC, strlen(nameC), (const uint8_t *)passC, strlen(passC), &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil];
    }
    NSLog(@"OCTSubmanagerGroupImpl: joinGroupWithChatId result=%u err=%d", result, err);
    return result;
}

- (BOOL)inviteFriend:(OCTFriendNumber)friendNumber toGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:nil]; return NO; }
    int err = 0;
    bool result = tox_group_invite_friend(tox, (uint32_t)friendNumber, groupNumber, &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:nil];
    }
    return result;
}

- (OCTGroupNumber)acceptInviteWithData:(NSData *)inviteData name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil]; return UINT32_MAX; }
    int err = 0;
    const char *nameC = name ? [name UTF8String] : "";
    const char *passC = password ? [password UTF8String] : "";
    uint32_t result = tox_group_invite_accept(tox, 0, [inviteData bytes], [inviteData length], (const uint8_t *)nameC, strlen(nameC), (const uint8_t *)passC, strlen(passC), &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil];
    }
    return result;
}

- (uint32_t)sendMessage:(NSData *)message toGroup:(OCTGroupNumber)groupNumber type:(OCTToxMessageType)type error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendMessage userInfo:nil]; return 0; }
    int err = 0;
    uint32_t result = tox_group_send_message(tox, groupNumber, (int)type, [message bytes], [message length], &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendMessage userInfo:nil];
    }
    return result;
}

- (BOOL)sendCustomPacket:(NSData *)packet toGroup:(OCTGroupNumber)groupNumber lossless:(BOOL)lossless error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendCustomPacket userInfo:nil]; return NO; }
    int err = 0;
    bool result = tox_group_send_custom_packet(tox, groupNumber, lossless, [packet bytes], [packet length], &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSendCustomPacket userInfo:nil];
    }
    return result;
}

- (BOOL)leaveGroup:(OCTGroupNumber)groupNumber withMessage:(NSString *)message error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorLeave userInfo:nil]; return NO; }
    int err = 0;
    const char *msgC = message ? [message UTF8String] : "";
    bool result = tox_group_leave(tox, groupNumber, (const uint8_t *)msgC, strlen(msgC), &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorLeave userInfo:nil];
    }
    return result;
}

- (BOOL)setTopic:(NSString *)topic forGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetTopic userInfo:nil]; return NO; }
    int err = 0;
    const char *topicC = topic ? [topic UTF8String] : "";
    bool result = tox_group_set_topic(tox, groupNumber, (const uint8_t *)topicC, strlen(topicC), &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetTopic userInfo:nil];
    }
    return result;
}

- (BOOL)kickPeer:(OCTGroupPeerNumber)peerNumber fromGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorKickPeer userInfo:nil]; return NO; }
    int err = 0;
    bool result = tox_group_kick_peer(tox, groupNumber, peerNumber, &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorKickPeer userInfo:nil];
    }
    return result;
}

- (BOOL)setRole:(OCTGroupRole)role forPeer:(OCTGroupPeerNumber)peerNumber inGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetRole userInfo:nil]; return NO; }
    int err = 0;
    bool result = tox_group_set_role(tox, groupNumber, peerNumber, (int)role, &err);
    if (err != 0 && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorSetRole userInfo:nil];
    }
    return result;
}

- (NSData *)getChatIdForGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    void *tox = _tox.tox;
    if (!tox) { if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGetChatId userInfo:nil]; return nil; }
    int err = 0;
    uint8_t chatId[TOX_GROUP_CHAT_ID_SIZE];
    bool result = tox_group_get_chat_id(tox, groupNumber, chatId, &err);
    if (!result || err != 0) {
        if (error) *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGetChatId userInfo:nil];
        return nil;
    }
    return [NSData dataWithBytes:chatId length:TOX_GROUP_CHAT_ID_SIZE];
}

- (uint32_t)getGroupNumberGroups {
    void *tox = _tox.tox;
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

static void groupInviteCallback(void *tox, uint32_t friend_number, const uint8_t *invite_data, size_t length, const uint8_t *group_name, size_t group_name_length, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSData *inviteData = [NSData dataWithBytes:invite_data length:length];
        NSString *groupName = group_name_length > 0 ? [[NSString alloc] initWithBytes:group_name length:group_name_length encoding:NSUTF8StringEncoding] : @"";
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:inviteReceived:fromFriend:groupName:)]) {
                [impl.delegate groupSubmanager:impl inviteReceived:inviteData fromFriend:friend_number groupName:groupName];
            }
        });
    }
}

static void groupMessageCallback(void *tox, uint32_t group_number, uint32_t peer_number, int type, const uint8_t *message, size_t length, uint32_t message_id, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSData *messageData = [NSData dataWithBytes:message length:length];
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:messageReceived:fromPeer:inGroup:type:messageId:)]) {
                [impl.delegate groupSubmanager:impl messageReceived:messageData fromPeer:peer_number inGroup:group_number type:type messageId:message_id];
            }
        });
    }
}

static void groupPrivateMessageCallback(void *tox, uint32_t group_number, uint32_t peer_number, int type, const uint8_t *message, size_t length, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSData *messageData = [NSData dataWithBytes:message length:length];
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:privateMessageReceived:fromPeer:inGroup:type:)]) {
                [impl.delegate groupSubmanager:impl privateMessageReceived:messageData fromPeer:peer_number inGroup:group_number type:type];
            }
        });
    }
}

static void groupCustomPacketCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *data, size_t length, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSData *packetData = [NSData dataWithBytes:data length:length];
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:customPacketReceived:fromPeer:inGroup:)]) {
                [impl.delegate groupSubmanager:impl customPacketReceived:packetData fromPeer:peer_number inGroup:group_number];
            }
        });
    }
}

static void groupPeerJoinCallback(void *tox, uint32_t group_number, uint32_t peer_number, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:peerJoined:inGroup:)]) {
                [impl.delegate groupSubmanager:impl peerJoined:peer_number inGroup:group_number];
            }
        });
    }
}

static void groupPeerExitCallback(void *tox, uint32_t group_number, uint32_t peer_number, int exit_type, const uint8_t *name, size_t name_length, const uint8_t *part_message, size_t part_message_length, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSString *peerName = name_length > 0 ? [[NSString alloc] initWithBytes:name length:name_length encoding:NSUTF8StringEncoding] : @"";
        NSString *partMsg = part_message_length > 0 ? [[NSString alloc] initWithBytes:part_message length:part_message_length encoding:NSUTF8StringEncoding] : nil;
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:peerLeft:inGroup:exitType:name:partMessage:)]) {
                [impl.delegate groupSubmanager:impl peerLeft:peer_number inGroup:group_number exitType:exit_type name:peerName partMessage:partMsg];
            }
        });
    }
}

static void groupTopicCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *topic, size_t length, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSString *topicStr = length > 0 ? [[NSString alloc] initWithBytes:topic length:length encoding:NSUTF8StringEncoding] : @"";
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:topicChanged:inGroup:byPeer:)]) {
                [impl.delegate groupSubmanager:impl topicChanged:topicStr inGroup:group_number byPeer:peer_number];
            }
        });
    }
}

static void groupSelfJoinCallback(void *tox, uint32_t group_number, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:selfJoinedGroup:)]) {
                [impl.delegate groupSubmanager:impl selfJoinedGroup:group_number];
            }
        });
    }
}

static void groupJoinRejectedCallback(void *tox, uint32_t group_number, int reject_type, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:joinRejected:inGroup:)]) {
                [impl.delegate groupSubmanager:impl joinRejected:reject_type inGroup:group_number];
            }
        });
    }
}

static void groupPeerNameCallback(void *tox, uint32_t group_number, uint32_t peer_number, const uint8_t *name, size_t length, void *user_data) {
    @autoreleasepool {
        OCTSubmanagerGroupImpl *impl = (__bridge OCTSubmanagerGroupImpl *)user_data;
        if (!impl) return;
        NSString *nameStr = length > 0 ? [[NSString alloc] initWithBytes:name length:length encoding:NSUTF8StringEncoding] : @"";
        dispatchToMain(^{
            if (impl.delegate && [impl.delegate respondsToSelector:@selector(groupSubmanager:peerNameChanged:inGroup:newName:)]) {
                [impl.delegate groupSubmanager:impl peerNameChanged:peer_number inGroup:group_number newName:nameStr];
            }
        });
    }
}
