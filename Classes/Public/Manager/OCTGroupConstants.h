// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "OCTToxConstants.h"

typedef uint32_t OCTGroupNumber;
typedef uint32_t OCTGroupPeerNumber;
typedef OCTToxFriendNumber OCTFriendNumber;

typedef NS_ENUM(NSInteger, OCTGroupPrivacyState) {
    OCTGroupPrivacyStatePrivate = 0,
    OCTGroupPrivacyStatePublic = 1,
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
    OCTGroupExitTypeKicked = 3,
};

typedef NS_ENUM(NSInteger, OCTGroupRejectType) {
    OCTGroupRejectTypeUnknown = 0,
    OCTGroupRejectTypeInviteFailed = 1,
    OCTGroupRejectTypeJoinFailed = 2,
    OCTGroupRejectTypeNoPermission = 3,
};

typedef NS_ENUM(NSInteger, OCTSubmanagerGroupError) {
    OCTSubmanagerGroupErrorUnknown,
    OCTSubmanagerGroupErrorGroupNew,
    OCTSubmanagerGroupErrorGroupJoin,
    OCTSubmanagerGroupErrorInviteFriend,
    OCTSubmanagerGroupErrorInviteAccept,
    OCTSubmanagerGroupErrorSendMessage,
    OCTSubmanagerGroupErrorSendCustomPacket,
    OCTSubmanagerGroupErrorLeave,
    OCTSubmanagerGroupErrorSetTopic,
    OCTSubmanagerGroupErrorKickPeer,
    OCTSubmanagerGroupErrorSetRole,
    OCTSubmanagerGroupErrorGetChatId,
};

extern NSString *const OCTSubmanagerGroupErrorDomain;