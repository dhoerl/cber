# SNMPGet - mostly C but some ObjectiveC code to probe SNMPv1 device

Based on the excellent cber project developed by Dariusz Stojaczyk (https://github.com/darsto/cber). There were just a few minor issues with his code that were needed to allow multiple OID reading.

This link contains a really short and useful explanation, format, and example of a simple SNMPv1 message: https://www.rane.com/note161.html, and was invaluable in understanding the snmp.c code.

Dariusz Stojaczyk's originl code focused on the BER coding, and he hadn't really hyped how fully-featured his SNMPv1 code was. He is doing his project a great disservice by not doing that!

With just a few minor changes I was able to adapt it to request a dozen or so OIDs at once!

As an addition to his code is an early version of a SNMPGet ObjectiveC class that creates ObjectiveC strings and numbers instead of C strings and binary number, and also has netrorking code that uses dispatch objects to wait for responses and to read the data. ["select" based code is also there and commented out.]

## Usage

```c
SNMPGet *g = [[SNMPGet alloc] initWithAddress:@"192.168.7.101"];    // you supply the address

// Supply a list of defined objects in SNMPGet.m, or use their decimal dotted values
// The strings make it easier to understand whats going on)

NSArray *array = @[
    @"sysDescr",
    @"sysUpTime",
];

[g probeOIDs:array];    // probe the list
BOOL foo = [g readResponseWaitingDispatch:2];   // waiting 2 seconds here, results are in the SNMPGet object

// Currently you can add log messages to see what is returned - see devices[@"192.168.7.101"]

```

NOTE: ultimately I will make all the C functions static (both .h/.c), leave the .h include as is, then import the .c file at the bottom of the .m class. This will make all of these functions private to the ObjC class and prevent name space pollution in any app using the code.
