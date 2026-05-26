#import <objcTox/OCTSubmanagerGroupImpl.h>
#import <objcTox/OCTTox+Private.h>
#import <objcTox/OCTSubmanagerGroupDelegate.h>
#import <objcTox/OCTGroupConstants.h>

#import <toxcore/tox.h>

typedef uint32_t Tox_Group_Number;
typedef uint32_t Tox_Group_Peer_Number;
typedef uint32_t Tox_Group_Message_Id;

typedef enum Tox_Group_Exit_Type {
    TOX_GROUP_EXIT_TYPE_QUIT,
    TOX_GROUP_EXIT_TYPE_TIMEOUT,
    TOX_GROUP_EXIT_TYPE_DISCONNECTED,
    TOX_GROUP_EXIT_TYPE_SELF_DISCONNECTED,
} Tox_Group_Exit_Type;

typedef enum Tox_Group_Join_Fail {
    TOX_GROUP_JOIN_FAIL_PEER_LIMIT,
    TOX_GROUP_JOIN_FAIL_INVALID_PASSWORD,
    TOX_GROUP_JOIN_FAIL_UNKNOWN,
} Tox_Group_Join_Fail;

@interface OCTSubmanagerGroupImpl ()

@property (nonatomic, weak, readwrite) OCTTox *tox;
@property (nonatomic, assign, readwrite) id<OCTSubmanagerGroupDelegate> delegate;

@end

@implementation OCTSubmanagerGroupImpl

- (instancetype)initWithTox:(OCTTox *)tox delegate:(id<OCTSubmanagerGroupDelegate>)delegate {
    self = [super init];
    if (self) {
        _tox = tox;
        _delegate = delegate;
        [self setupCallbacks];
    }
    return self;
}

- (void)setupCallbacks {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) return;

    tox_callback_group_invite(tox, groupInviteCallback);
    tox_callback_group_message(tox, groupMessageCallback);
    tox_callback_group_private_message(tox, groupPrivateMessageCallback);
    tox_callback_group_peer_name(tox, groupPeerNameCallback);
    tox_callback_group_peer_join(tox, groupPeerJoinCallback);
    tox_callback_group_peer_exit(tox, groupPeerExitCallback);
    tox_callback_group_topic(tox, groupTopicCallback);
    tox_callback_group_self_join(tox, groupSelfJoinCallback);
    tox_callback_group_join_fail(tox, groupJoinFailCallback);
    tox_callback_group_custom_packet(tox, groupCustomPacketCallback);
}

- (OCTGroupNumber)createGroupWithName:(NSString *)name privacyState:(OCTGroupPrivacyState)privacyState error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:nil];
        }
        return UINT32_MAX;
    }

    Tox_Err_Group_New err = TOX_ERR_GROUP_NEW_OK;
    const char *nameC = name ? [name UTF8String] : "";
    size_t nameLen = strlen(nameC);

    NSString *selfName = self.tox.userName;
    const char *selfNameC = selfName ? [selfName UTF8String] : "";
    size_t selfNameLen = strlen(selfNameC);

    Tox_Group_Privacy_State privacy = (privacyState == OCTGroupPrivacyStatePrivate) ?
        TOX_GROUP_PRIVACY_STATE_PRIVATE : TOX_GROUP_PRIVACY_STATE_PUBLIC;

    Tox_Group_Number result = tox_group_new(tox, privacy,
        (const uint8_t *)nameC, nameLen,
        (const uint8_t *)selfNameC, selfNameLen,
        &err);

    NSLog(@"OCTSubmanagerGroupImpl: createGroupWithName result=%u err=%d", result, err);

    if (err != TOX_ERR_GROUP_NEW_OK && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupNew userInfo:nil];
    }

    return result;
}

- (OCTGroupNumber)joinGroupWithChatId:(NSData *)chatId name:(NSString *)name password:(NSString *)password error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil];
        }
        return UINT32_MAX;
    }

    if (!chatId || chatId.length != TOX_GROUP_CHAT_ID_SIZE) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil];
        }
        return UINT32_MAX;
    }

    Tox_Err_Group_Join err = TOX_ERR_GROUP_JOIN_OK;
    const char *nameC = name ? [name UTF8String] : "";
    size_t nameLen = strlen(nameC);
    const char *pwC = password ? [password UTF8String] : NULL;
    size_t pwLen = pwC ? strlen(pwC) : 0;

    Tox_Group_Number result = tox_group_join(tox,
        (const uint8_t *)chatId.bytes,
        (const uint8_t *)nameC, nameLen,
        (const uint8_t *)pwC, pwLen,
        &err);

    NSLog(@"OCTSubmanagerGroupImpl: joinGroupWithChatId result=%u err=%d", result, err);

    if (err != TOX_ERR_GROUP_JOIN_OK && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupJoin userInfo:nil];
    }

    return result;
}

- (BOOL)inviteFriend:(OCTFriendNumber)friendNumber toGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:nil];
        }
        return NO;
    }

    Tox_Err_Group_Invite_Friend err = TOX_ERR_GROUP_INVITE_FRIEND_OK;
    bool result = tox_group_invite_friend(tox, groupNumber, friendNumber, &err);

    NSLog(@"OCTSubmanagerGroupImpl: inviteFriend result=%d err=%d", result, err);

    if (!result && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteFriend userInfo:nil];
    }

    return result ? YES : NO;
}

- (OCTGroupNumber)acceptInviteWithFriendNumber:(OCTFriendNumber)friendNumber inviteData:(NSData *)inviteData name:(NSString *)name error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil];
        }
        return UINT32_MAX;
    }

    if (!inviteData) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil];
        }
        return UINT32_MAX;
    }

    Tox_Err_Group_Invite_Accept err = TOX_ERR_GROUP_INVITE_ACCEPT_OK;
    const char *nameC = name ? [name UTF8String] : "";
    size_t nameLen = strlen(nameC);

    Tox_Group_Number result = tox_group_invite_accept(tox, friendNumber,
        (const uint8_t *)inviteData.bytes, inviteData.length,
        (const uint8_t *)nameC, nameLen,
        NULL, 0,
        &err);

    NSLog(@"OCTSubmanagerGroupImpl: acceptInvite result=%u err=%d", result, err);

    if (err != TOX_ERR_GROUP_INVITE_ACCEPT_OK && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorInviteAccept userInfo:nil];
    }

    return result;
}

- (BOOL)leaveGroup:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupLeave userInfo:nil];
        }
        return NO;
    }

    Tox_Err_Group_Leave err = TOX_ERR_GROUP_LEAVE_OK;
    bool result = tox_group_leave(tox, groupNumber, NULL, 0, &err);

    NSLog(@"OCTSubmanagerGroupImpl: leaveGroup result=%d err=%d", result, err);

    if (!result && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupLeave userInfo:nil];
    }

    return result ? YES : NO;
}

- (BOOL)changeGroup:(OCTGroupNumber)groupNumber topic:(NSString *)topic error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupTopicSet userInfo:nil];
        }
        return NO;
    }

    Tox_Err_Group_Topic_Set err = TOX_ERR_GROUP_TOPIC_SET_OK;
    const char *topicC = topic ? [topic UTF8String] : "";
    size_t topicLen = strlen(topicC);

    bool result = tox_group_set_topic(tox, groupNumber, (const uint8_t *)topicC, topicLen, &err);

    NSLog(@"OCTSubmanagerGroupImpl: changeGroupTopic result=%d err=%d", result, err);

    if (!result && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupTopicSet userInfo:nil];
    }

    return result ? YES : NO;
}

- (OCTGroupMessageId)sendMessageToGroup:(OCTGroupNumber)groupNumber message:(NSString *)message type:(OCTGroupMessageType)type error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSendMessage userInfo:nil];
        }
        return UINT32_MAX;
    }

    Tox_Err_Group_Send_Message err = TOX_ERR_GROUP_SEND_MESSAGE_OK;
    const char *msgC = message ? [message UTF8String] : "";
    size_t msgLen = strlen(msgC);

    Tox_Message_Type msgType = (type == OCTGroupMessageTypeAction) ? TOX_MESSAGE_TYPE_ACTION : TOX_MESSAGE_TYPE_NORMAL;

    Tox_Group_Message_Id result = tox_group_send_message(tox, groupNumber, msgType, (const uint8_t *)msgC, msgLen, &err);

    NSLog(@"OCTSubmanagerGroupImpl: sendMessageToGroup result=%u err=%d", result, err);

    if (err != TOX_ERR_GROUP_SEND_MESSAGE_OK && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSendMessage userInfo:nil];
    }

    return result;
}

- (BOOL)sendCustomPacketToGroup:(OCTGroupNumber)groupNumber lossless:(BOOL)lossless data:(NSData *)data error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSendCustomPacket userInfo:nil];
        }
        return NO;
    }

    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSendCustomPacket userInfo:nil];
        }
        return NO;
    }

    Tox_Err_Group_Send_Custom_Packet err = TOX_ERR_GROUP_SEND_CUSTOM_PACKET_OK;
    bool result = tox_group_send_custom_packet(tox, groupNumber, lossless, (const uint8_t *)data.bytes, data.length, &err);

    NSLog(@"OCTSubmanagerGroupImpl: sendCustomPacket result=%d err=%d", result, err);

    if (!result && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSendCustomPacket userInfo:nil];
    }

    return result ? YES : NO;
}

- (NSData *)getGroupChatId:(OCTGroupNumber)groupNumber error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupGetChatId userInfo:nil];
        }
        return nil;
    }

    uint8_t chatId[TOX_GROUP_CHAT_ID_SIZE];
    Tox_Err_Group_State_Query err = TOX_ERR_GROUP_STATE_QUERY_OK;
    bool result = tox_group_get_chat_id(tox, groupNumber, chatId, &err);

    if (!result) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupGetChatId userInfo:nil];
        }
        return nil;
    }

    return [NSData dataWithBytes:chatId length:TOX_GROUP_CHAT_ID_SIZE];
}

- (NSUInteger)getNumberGroups {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) return 0;
    return tox_group_get_number_groups(tox);
}

- (BOOL)kickPeerFromGroup:(OCTGroupNumber)groupNumber peerId:(OCTGroupPeerNumber)peerId error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupKickPeer userInfo:nil];
        }
        return NO;
    }

    Tox_Err_Group_Kick_Peer err = TOX_ERR_GROUP_KICK_PEER_OK;
    bool result = tox_group_kick_peer(tox, groupNumber, peerId, &err);

    if (!result && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupKickPeer userInfo:nil];
    }

    return result ? YES : NO;
}

- (BOOL)setPeerRoleInGroup:(OCTGroupNumber)groupNumber peerId:(OCTGroupPeerNumber)peerId role:(OCTGroupRole)role error:(NSError **)error {
    Tox *tox = (Tox *)self.tox.tox;
    if (!tox) {
        if (error) {
            *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSetRole userInfo:nil];
        }
        return NO;
    }

    Tox_Group_Role toxRole;
    switch (role) {
        case OCTGroupRoleFounder:   toxRole = TOX_GROUP_ROLE_FOUNDER; break;
        case OCTGroupRoleModerator: toxRole = TOX_GROUP_ROLE_MODERATOR; break;
        case OCTGroupRoleUser:      toxRole = TOX_GROUP_ROLE_USER; break;
        case OCTGroupRoleObserver:  toxRole = TOX_GROUP_ROLE_OBSERVER; break;
        default:                    toxRole = TOX_GROUP_ROLE_USER; break;
    }

    Tox_Err_Group_Set_Role err = TOX_ERR_GROUP_SET_ROLE_OK;
    bool result = tox_group_set_role(tox, groupNumber, peerId, toxRole, &err);

    if (!result && error) {
        *error = [NSError errorWithDomain:OCTSubmanagerGroupErrorDomain code:OCTSubmanagerGroupErrorGroupSetRole userInfo:nil];
    }

    return result ? YES : NO;
}

#pragma mark - Callbacks

static void groupInviteCallback(Tox *tox, Tox_Friend_Number friendNumber,
    const uint8_t *inviteData, size_t inviteDataLength,
    const uint8_t *groupName, size_t groupNameLength,
    void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSData *inviteDataNS = [NSData dataWithBytes:inviteData length:inviteDataLength];
    NSString *groupNameNS = [[NSString alloc] initWithBytes:groupName length:groupNameLength encoding:NSUTF8StringEncoding];

    [manager.delegate groupInviteReceivedFromFriend:friendNumber inviteData:inviteDataNS groupName:groupNameNS];
}

static void groupMessageCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, Tox_Message_Type type,
    const uint8_t *message, size_t length,
    Tox_Group_Message_Id messageId, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSString *messageNS = [[NSString alloc] initWithBytes:message length:length encoding:NSUTF8StringEncoding];
    OCTGroupMessageType msgType = (type == TOX_MESSAGE_TYPE_ACTION) ? OCTGroupMessageTypeAction : OCTGroupMessageTypeNormal;

    [manager.delegate groupMessageReceivedInGroup:groupNumber peerId:peerId message:messageNS type:msgType messageId:messageId];
}

static void groupPrivateMessageCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, Tox_Message_Type type,
    const uint8_t *message, size_t length,
    Tox_Group_Message_Id messageId, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSString *messageNS = [[NSString alloc] initWithBytes:message length:length encoding:NSUTF8StringEncoding];
    OCTGroupMessageType msgType = (type == TOX_MESSAGE_TYPE_ACTION) ? OCTGroupMessageTypeAction : OCTGroupMessageTypeNormal;

    [manager.delegate groupPrivateMessageReceivedInGroup:groupNumber peerId:peerId message:messageNS type:msgType messageId:messageId];
}

static void groupPeerNameCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, const uint8_t *name,
    size_t nameLength, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSString *nameNS = [[NSString alloc] initWithBytes:name length:nameLength encoding:NSUTF8StringEncoding];
    [manager.delegate groupPeerNameChangedInGroup:groupNumber peerId:peerId name:nameNS];
}

static void groupPeerJoinCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    [manager.delegate groupPeerJoinedGroup:groupNumber peerId:peerId];
}

static void groupPeerExitCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, Tox_Group_Exit_Type exitType,
    const uint8_t *name, size_t nameLength,
    const uint8_t *partMessage, size_t partMessageLength,
    void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSString *nameNS = name ? [[NSString alloc] initWithBytes:name length:nameLength encoding:NSUTF8StringEncoding] : nil;
    NSString *partMsg = partMessage ? [[NSString alloc] initWithBytes:partMessage length:partMessageLength encoding:NSUTF8StringEncoding] : nil;

    [manager.delegate groupPeerLeftGroup:groupNumber peerId:peerId name:nameNS partMessage:partMsg];
}

static void groupTopicCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, const uint8_t *topic,
    size_t topicLength, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSString *topicNS = [[NSString alloc] initWithBytes:topic length:topicLength encoding:NSUTF8StringEncoding];
    [manager.delegate groupTopicChangedInGroup:groupNumber peerId:peerId topic:topicNS];
}

static void groupSelfJoinCallback(Tox *tox, Tox_Group_Number groupNumber, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    [manager.delegate groupSelfJoinedGroup:groupNumber];
}

static void groupJoinFailCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Join_Fail failType, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    [manager.delegate groupJoinFailedForGroup:groupNumber failType:(OCTGroupJoinFail)failType];
}

static void groupCustomPacketCallback(Tox *tox, Tox_Group_Number groupNumber,
    Tox_Group_Peer_Number peerId, const uint8_t *data,
    size_t length, void *userData) {
    OCTSubmanagerGroupImpl *manager = [OCTSubmanagerGroupImpl managerForTox:tox];
    if (!manager || !manager.delegate) return;

    NSData *dataNS = [NSData dataWithBytes:data length:length];
    [manager.delegate groupCustomPacketReceivedInGroup:groupNumber peerId:peerId data:dataNS];
}

+ (OCTSubmanagerGroupImpl *)managerForTox:(void *)toxPtr {
    return nil;
}

@end
