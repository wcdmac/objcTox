// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import <objcTox/OCTSubmanagerGroup.h>

@interface OCTSubmanagerGroupImpl : NSObject <OCTSubmanagerGroup>

@property (nonatomic, assign) void *toxPointer;

- (instancetype)initWithToxPointer:(void *)toxPointer;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end