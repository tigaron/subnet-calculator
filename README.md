# CLI tool to assist subnet calculation

A tool to speed up subnet calculation, with additional features to help in networking.

## Usage
`$ subnet --help`

```
Subnet Calculator v.0.8
Bash script to assist subnetting process
Usage: subnet [options]

Options:
        --help              Print this help page
        -m, --mode          Change mode of the script to run
        -i, --ip            Provide the IP address
        -c, --cidr          Provide the CIDR
        -n, --netmask       Provide the Netmask
        -s, --subnets       Expected number of subnets
        -h, --hosts         Expected number of available hosts per subnet
        -t, --try           Number of subnets' detail to print

Modes:
        1 - Get network information from a pair of IP address and its CIDR notation e.g. 10.0.0.0/16
        2 - Perform subnet calculation for for the amount of required hosts per subnet or required subnets
        3 - Check the type and class of an IP address
```


### Mode 1

Get network information from a pair of IP address and its CIDR notation e.g. 10.0.0.0/16

`$ subnet -m=1 -i=192.168.141.111 -c=28`
```
  +                  +                +                  +                      +                                   +                    +
  | Network Address  | CIDR Notation  | Subnet Mask      | Useable Host/Subnet  | Host Address Range                | Broadcast Address  |
  +                  +                +                  +                      +                                   +                    +
  | 192.168.141.96   | 28             | 255.255.255.240  | 14                   | 192.168.141.97 - 192.168.141.110  | 192.168.141.111    |
  +                  +                +                  +                      +                                   +                    +
```

### Mode 2

Perform subnet calculation for for the amount of required hosts per subnet or required subnets

#### Example 1 - Provide the required amount of subnets

`$ subnet -m=2 -i=192.168.141.0 -s=2`
```
  +       +           +         +                +                        +                       +
  | CIDR  | IP Class  | Type    | Subnet Amount  | Total Available Hosts  | Network Address List  |
  +       +           +         +                +                        +                       +
  | 25    | C         | subnet  | 2              | 252                    | See below             |
  +       +           +         +                +                        +                       +

Subnet Details:
  +            +                  +                +                  +                      +                                    +                    +
  | Subnet ID  | Network Address  | CIDR Notation  | Subnet Mask      | Useable Host/Subnet  | Host Address Range                 | Broadcast Address  |
  +            +                  +                +                  +                      +                                    +                    +
  | 1          | 192.168.141.0    | 25             | 255.255.255.128  | 126                  | 192.168.141.1 - 192.168.141.126    | 192.168.141.127    |
  | 2          | 192.168.141.128  | 25             | 255.255.255.128  | 126                  | 192.168.141.129 - 192.168.141.254  | 192.168.141.255    |
  +            +                  +                +                  +                      +                                    +                    +
```

#### Example 2 - Provide the required hosts per subnet

`$ subnet -m=2 -i=192.168.141.0 -h=50 -t=all`
```
  +       +           +         +                +                        +                       +
  | CIDR  | IP Class  | Type    | Subnet Amount  | Total Available Hosts  | Network Address List  |
  +       +           +         +                +                        +                       +
  | 26    | C         | subnet  | 4              | 248                    | See below             |
  +       +           +         +                +                        +                       +

Subnet Details:
  +            +                  +                +                  +                      +                                    +                    +
  | Subnet ID  | Network Address  | CIDR Notation  | Subnet Mask      | Useable Host/Subnet  | Host Address Range                 | Broadcast Address  |
  +            +                  +                +                  +                      +                                    +                    +
  | 1          | 192.168.141.0    | 26             | 255.255.255.192  | 62                   | 192.168.141.1 - 192.168.141.62     | 192.168.141.63     |
  | 2          | 192.168.141.64   | 26             | 255.255.255.192  | 62                   | 192.168.141.65 - 192.168.141.126   | 192.168.141.127    |
  | 3          | 192.168.141.128  | 26             | 255.255.255.192  | 62                   | 192.168.141.129 - 192.168.141.190  | 192.168.141.191    |
  | 4          | 192.168.141.192  | 26             | 255.255.255.192  | 62                   | 192.168.141.193 - 192.168.141.254  | 192.168.141.255    |
  +            +                  +                +                  +                      +                                    +                    +
```
By default, if `-t` or `--try` parameter were not specified, the script will only provide two (2) entries in the subnet details table in order to save computing power.

### Mode 3

Check the type and class of an IP address

`$ subnet -m=3 -i=10.11.12.13`

```
  +              +        +          +
  | IP Address   | Class  | Type     |
  +              +        +          +
  | 10.11.12.13  | A      | Private  |
  +              +        +          +
```