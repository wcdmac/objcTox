#import <Foundation/Foundation.h>

typedef uint32_t OCTGroupNumber;
typedef uint32_t OCTGroupPeerNumber;
typedef uint32_t OCTGroupMessageId;

typedef NS_ENUM(NSInteger, OCTGroupPrivacyState) {
    OCTGroupPrivacyStatePublic = 0,
    OCTGroupPrivacyStatePrivate = 1,
};

typedef NS_ENUM(NSInteger, OCTGroupRole) {
    OCTGroupRoleFounder = 0,
    OCTGroupRoleModerator = 1,
    OCTGroupRoleUser = 2,
    OCTGroupRoleObserver = 3,
};

typedef NS_ENUM(NSInteger, OCTGroupExitType) {
    OCTGroupExitTypeQuit = 0,
    OCTGroupExitTypeTimeout = 1,
    OCTGroupExitTypeDisconnected = 2,
    OCTGroupExitTypeSelfDisconnected = 3,
};

typedef NS_ENUM(NSInteger, OCTGroupRejectType) {
    OCTGroupRejectTypePeerLimit = 0,
    OCTGroupRejectTypeInvalidPassword = 1,
    OCTGroupRejectTypeUnknown = 2,
};

typedef NS_ENUM(NSInteger, OCTGroupMessageType) {
    OCTGroupMessageTypeNormal = 0,
    OCTGroupMessageTypeAction = 1,
};

typedef NS_ENUM(NSInteger, OCTSubmanagerGroupError) {
    OCTSubmanagerGroupErrorGroupNew = 1,
    OCTSubmanagerGroupErrorGroupJoin = 2,
    OCTSubmanagerGroupErrorInviteFriend = 3,
    OCTSubmanagerGroupErrorInviteAccept = 4,
    OCTSubmanagerGroupErrorGroupLeave = 5,
    OCTSubmanagerGroupErrorGroupTopicSet = 6,
    OCTSubmanagerGroupErrorGroupSendMessage = 7,
    OCTSubmanagerGroupErrorGroupSendCustomPacket = 8,
    OCTSubmanagerGroupErrorGroupGetChatId = 9,
    OCTSubmanagerGroupErrorGroupKickPeer = 10,
    OCTSubmanagerGroupErrorGroupSetRole = 11,
};

extern NSString *const OCTSubmanagerGroupErrorDomain;