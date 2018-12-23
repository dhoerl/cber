# SNMPGet - mostly C but some ObjectiveC code to proble SNMPv1 device

Based on the excellent cber project developed by Dariusz Stojaczyk. There were just a few minor issues with his code that were needed to allow multiple OID reading.

Dariusz Stojaczyk's originl code focused on the BER coding, and he hadn't really hyped how fully-featured his SNMPv1 code was. He is doing his project a great disservice but not doing that!

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

This library should be used directly inside the application. Simply copy the `ber.c` and `ber.h` files to your project.

For full usage example, please see snmp.c file. It is an SNMPv1 codec which uses BER library under the hood. It includes all error checks and is user-ready.

## Benchmarks

See performance comparisons in [BENCHMARK.md](BENCHMARK.md).

## Running tests

This library comes with a simple unit tests that can be run as following.

```
git clone git@github.com:darsto/ber.git
cd ber
make
./ber-test
```

You should see some output similar to the one below.

```
# Testing variable-length-integer coding.
ber_encode_vlint(42) = {
  00000000: 2a                                      | *
}
ber_encode_vlint(67) = {
  00000000: 43                                      | C
}
ber_encode_vlint(128) = {
  00000000: 8100                                    | ..
}
ber_encode_vlint(129) = {
  00000000: 8101                                    | ..
}
ber_encode_vlint(179) = {
  00000000: 8133                                    | .3
}

[...]

# Testing BER integer coding
ber_encode_int(42) = {
  00000000: 0201 2a                                 | ..*
}
ber_encode_int(67) = {
  00000000: 0201 43                                 | ..C
}
ber_encode_int(128) = {
  00000000: 0201 80                                 | ...
}
ber_encode_int(129) = {
  00000000: 0201 81                                 | ...
}
ber_encode_int(179) = {
  00000000: 0201 b3                                 | ...
}

[...]

# Testing BER string coding
ber_encode_string("a") = {
  00000000: 0401 61                                 | ..a
}
ber_encode_string("ab") = {
  00000000: 0402 6162                               | ..ab
}
ber_encode_string("test123") = {
  00000000: 0407 7465 7374 3132 33                  | ..test123
}
ber_encode_string("testing_longer_name") = {
  00000000: 0413 7465 7374 696e 675f 6c6f 6e67 6572 | ..testing_longer
  00000010: 5f6e 616d 65                            | _name
}

[...]

# Testing fprintf syntax-like coding.
ber_fprintf("%u%u%s", 64, 103, "testing_strings_123") = {
  00000000: 0140 0201 6704 1374 6573 7469 6e67 5f73 | .@..g..testing_s
  00000010: 7472 696e 6773 5f31 3233                | trings_123
}

[...]
```
