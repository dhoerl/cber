//
//  SNMPGet.m
//  SNMPGet
//
//  Created by David Hoerl on 12/9/18.
//  Copyright © 2018 David Hoerl. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/select.h>

#import "SNMPGet.h"

#import "ber.h"
#import "snmp.h"


static NSDictionary *mibName2Num;
static NSDictionary *mibNum2Name;

static NSString *socketKey = @"socketKey";
static NSMutableDictionary *devices;
static dispatch_queue_t queue;

static void OIDstr2nums(NSString *OIDstr, uint32_t *OID) {
    assert([OIDstr length] > 0);

    NSString *input;
    if ([OIDstr characterAtIndex:0] != '1') {
        input = mibName2Num[OIDstr];
        assert(input);
    } else {
        input = OIDstr;
    }

    NSArray *numbers = [input componentsSeparatedByString:@"."];

    int i = 0;
    for(NSString *number in numbers) {
        OID[i++] = [number intValue];
    }
    OID[i] = SNMP_MSG_OID_END;
}

static NSString * OIDnums2str(uint32_t *ptr) {
    NSMutableString *OIDstr = [NSMutableString new];
    while(*ptr != SNMP_MSG_OID_END) {
        [OIDstr appendFormat:@"%s%d", [OIDstr length] ? "." : "", *ptr];
        ptr += 1;
    }
    return OIDstr;
}


@implementation SNMPGet {
    int socket_fd;
    int requestID;
    NSString *ipAddress;
    NSMutableDictionary *snmp;
    dispatch_semaphore_t sema;
    dispatch_source_t source;
}

+ (void)initialize {
    if ([self class] == [SNMPGet class]) {
        mibName2Num = @{
            @"sysDescr"                     : @"1.3.6.1.2.1.1.1.0",                // Full name
            @"sysUpTime"                    : @"1.3.6.1.2.1.1.3.0",                // hundreds of a second
        };
        NSMutableDictionary *dict = [NSMutableDictionary new];
        [mibName2Num enumerateKeysAndObjectsUsingBlock:^(NSString  *key, NSString  *val, BOOL *stop) {
            dict[val] = key;
        }];
        mibNum2Name = [dict copy];

        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, QOS_MIN_RELATIVE_PRIORITY/2);
        queue = dispatch_queue_create("snmpMonitor.salido.com", attr);
        assert(queue);
    }
}

- (instancetype)initWithAddress:(NSString *)addr {
    self = [super init];

    ipAddress = addr;

    __block NSMutableDictionary *d;
    dispatch_sync(queue, ^{
        d = devices[addr];
    });


    if (d == nil) {
        d = [NSMutableDictionary new];
        dispatch_async(queue, ^{
            devices[addr] = d;
        });
        if ([self socketStart]) {
            d[socketKey] = @(socket_fd);
        }
    } else {
        socket_fd = [d[socketKey] intValue];
    }
    snmp = d;

    sema = dispatch_semaphore_create(0);
    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, socket_fd, 0, queue); // dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));
    dispatch_resume(source);

    __typeof__(self) __weak weakSelf = self;
    dispatch_block_t block = ^void(void){
         __typeof__(self) strongSelf = weakSelf;
         if (strongSelf == nil) { return; }

        ssize_t bytes_read = dispatch_source_get_data(strongSelf->source);
        NSLog(@"bytes_read1 %ld", bytes_read);
        if (bytes_read > 0) {
            NSMutableData *data = [NSMutableData dataWithLength:bytes_read];
            ssize_t count = recv(strongSelf->socket_fd, [data mutableBytes], bytes_read, 0);
            if (count == bytes_read) {
                NSDictionary *dict = [SNMPGet buildResponseWithData:data];
                if ([dict count]) {
                    dispatch_async(queue, ^{
                        [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL * _Nonnull stop) {
                            (strongSelf->snmp)[key] = value;
                        }];
                    });
                }
            }
        }
        dispatch_semaphore_signal(strongSelf->sema);
    };
    dispatch_source_set_event_handler(source, block);

    return self;
}
- (void)dealloc {
    //[self close];
}

- (BOOL)probeOIDs:(NSArray<NSString *> *)oids {
    NSData *data = [self buildRequest:oids];
    [self sendOIDs:data];
    return YES;
}

- (NSData *)buildRequest:(NSArray<NSString *> *)oids {
    uint32_t count = (uint32_t)oids.count;
    ssize_t bufferSize = 40+count*40;   // close enought
    uint8_t *buf = (uint8_t *)malloc(bufferSize);    // much more than I need

    requestID += 1;
    struct snmp_msg_header header = {
        0,
        "public",
        SNMP_DATA_T_PDU_GET_REQUEST,
        requestID,
        0,
        0
    };

    struct snmp_varbind varbinds[count];
    __block struct snmp_varbind *ptr = varbinds;
    [oids enumerateObjectsUsingBlock:^(NSString * _Nonnull oid, NSUInteger idx, BOOL * _Nonnull stop) {
        OIDstr2nums(oid, ptr->oid);
        ptr->value_type = SNMP_DATA_T_NULL;
        ptr += 1;
    }];

    uint8_t *msg = snmp_encode_msg(buf+bufferSize-1, &header, (uint32_t)oids.count, varbinds);
    //printf("BER %d %d\n", header.error_status, header.error_index);
    int len = (int)((buf+bufferSize) - msg);
    NSData *data = [NSData dataWithBytes:msg length:len];

    return data;
}

- (void)close {
    if (socket_fd > 0) {
        close(socket_fd);
    }
}

#pragma mark connect

#if 0
// Some unexplained issue
extern int select(int nfds, fd_set *restrict readfds, fd_set *restrict writefds, fd_set *restrict errorfds, struct timeval *restrict timeout);
#endif

// SWIFT: https://stackoverflow.com/questions/28295486/how-to-implement-udp-client-and-send-data-in-swift-on-iphone
- (BOOL)socketStart {
    int ret;

    const char *src = [ipAddress cStringUsingEncoding:NSASCIIStringEncoding];

    ret = socket(PF_INET, SOCK_DGRAM, 0);   // DGRAM makes it UDP
    if (ret<0) { return NO; }
    socket_fd = ret;

    int flags = fcntl(socket_fd, F_GETFL);
    flags |= O_NONBLOCK;
    fcntl(socket_fd, F_SETFL, flags);

    struct sockaddr_in sin = { 0 };
    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(161);
    ret = inet_pton(AF_INET, src, &(sin.sin_addr));
    if (ret<0) { return NO; }

    ret = connect(socket_fd, (struct sockaddr *)&sin, sizeof(sin));
    if (ret<0) { return NO; }

    return YES;
}

- (BOOL)sendOIDs:(NSData *)data {
    ssize_t bytes_sent;

    bytes_sent = send(socket_fd, data.bytes, data.length, 0);
    NSLog(@"SEND %ld bytes", bytes_sent);
    if (bytes_sent != data.length) {
        return NO;
    } else {
        return YES;
    }
}

- (BOOL)readResponseWaitingDispatch:(int)waitTime {
    long ret = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, waitTime * NSEC_PER_SEC));
    NSLog(@"dispatch_semaphore_wait RETURN = %ld", ret);

    return ret == 0;
}

#if 0   // Don't need this on iOS but others might
- (nullable NSArray *)readResponseWaitingSelect:(int)waitTime {
    struct timeval tv;
    tv.tv_sec = waitTime;
    tv.tv_usec = 0;

    fd_set original_socket;
    fd_set readfds;

    FD_ZERO(&original_socket);
    FD_ZERO(&readfds);
    FD_SET(socket_fd, &original_socket);//instead of 0 put socket_fd
    FD_SET(socket_fd, &readfds);//instead of 0 put socket_fd
    int numfd = socket_fd + 1;

NSLog(@"START...");
    int ret = select(numfd, &readfds, NULL, NULL, &tv);
NSLog(@"...END");

    if (ret == -1)
    {
      perror("select"); // error occurred in select()
      return nil;
    }
    else if (ret == 0)
    {
      printf("Timeout occurred!  No data after 10.5 seconds.\n");
      return nil;
    }

    if (FD_ISSET(socket_fd, &readfds)) {
        FD_CLR(socket_fd, &readfds);

        unsigned char buf[1024];
        ssize_t bytes_read = recv(socket_fd, buf, 1024, 0);
NSLog(@"bytes_read %ld", bytes_read);
        if (bytes_read <= 0) {
            /* This means the other side closed the socket */
            return nil;
        }
        NSData *data = [NSData dataWithBytes:buf length:bytes_read];
        [self buildResponseWithData:data];
    }
    return [NSArray new];
}
#endif

+ (NSDictionary *)buildResponseWithData:(NSData *)data {
    uint8_t *buf = (uint8_t *)[data bytes];
    NSInteger buf_len = [data length];

    struct snmp_msg_header header = { 0 };
    uint32_t varbind_num = 20;
    struct snmp_varbind varbinds[varbind_num];

    NSLog(@"Got %td bytes", buf_len);
    uint8_t *buf_end = snmp_decode_msg(buf, (uint32_t)buf_len, &header, &varbind_num, varbinds);
    NSLog(@"ERROR err=%d index %d", header.error_status, header.error_index);

    if(buf_end == NULL) {
        NSLog(@"WTF!");
        return nil;
    }

    if (header.error_status != 0) {
        NSLog(@"ERROR RETURN!!! ret=%d index %d", header.error_status, header.error_index);
        return nil;
    }
    NSLog(@"Processed %td bytes", buf_end - buf);
    NSLog(@"varbind_num %d", varbind_num);

    NSMutableDictionary *dict = [NSMutableDictionary new];
    struct snmp_varbind *ptr = varbinds;

    for(int i=0; i<varbind_num; ++i) {
        NSString *oidName = mibNum2Name[ OIDnums2str(ptr->oid) ];
        NSString *s = [NSString stringWithFormat:@"OID: %@", oidName];

        switch (ptr->value_type) {
            case SNMP_DATA_T_INTEGER:
            case SNMP_DATA_T_COUNTER:
            case SNMP_DATA_T_GAUGE:
            case SNMP_DATA_T_TIMETICKS:
            case SNMP_DATA_T_INTERNET:

            NSLog(@"%@ INT %d", s, ptr->value.i);
            dict[oidName] = @(ptr->value.i);
            break;

        case SNMP_DATA_T_OCTET_STRING:
            NSLog(@"%@ STR \"%s\"", s, ptr->value.s);
            dict[oidName] = [NSString stringWithCString:ptr->value.s encoding:NSUTF8StringEncoding];
            break;

        default:
            NSLog(@"%@ VALUE TYPE %d", s, ptr->value_type);
            break;
        }
        ptr += 1;
    }

    return dict;
}

@end
