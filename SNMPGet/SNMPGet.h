//
//  SNMPGet.h
//  SNMPGet
//
//  Created by David Hoerl on 12/9/18.
//  Copyright © 2018 David Hoerl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SNMPGet : NSObject

- (instancetype)initWithAddress:(NSString *)ipAddress;

- (BOOL)probeOIDs:(NSArray<NSString *> *)oids;
//- (nullable NSArray *)readResponseWaitingSelect:(int)waitTime;
- (BOOL)readResponseWaitingDispatch:(int)waitTime;

- (void)close;

@end

NS_ASSUME_NONNULL_END

