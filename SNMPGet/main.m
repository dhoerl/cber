//
//  main.m
//  SNMPGet
//
//  Created by David Hoerl on 12/7/18.
//  Copyright © 2018 Salido. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SNMPGet.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        NSLog(@"Hello, World!");
        SNMPGet *g = [[SNMPGet alloc] initWithAddress:@"192.168.7.101"];

        NSArray *array = @[
            @"sysDescr",
            @"sysUpTime",
        ];

        [g probeOIDs:array];
        BOOL foo = [g readResponseWaitingDispatch:2];
        NSLog(@"FOO %d", foo);
    }
    return 0;
}
