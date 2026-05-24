iimport "OCTGroup.h"

@implementation OCTGroup

+ (NSString *)primaryKey {
    return @"uniqueIdentifier";
}

+ (NSArray *)indexedProperties {
    return @[@"groupNumber"];
}

@end