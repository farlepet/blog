---
layout: post
title:  "Running PTP Receiver on FreeBSD"
date:   2026-02-13 19:00:00 -0600
categories: freebsd
permalink: /posts/ptp_receiver_on_freebsd.html
---

A while back I installed a GPS-disciplined PTP (Precision Time Protocol) time server at home. This was
partially due to a contract project that was using PTP (but totally did not
require having such a dedicated time server), but mostly just because I am
interested in time. On most of my hard-wired machines I already have them set
up to use PTP as their time source (everything else will be using the NTP server
on this time server). I recently installed FreeBSD on an old server (and on some
workstations), but never got around to setting up PTP on it. I saw almost no
mention of using PTP on FreeBSD on the internet, so I decided I would do a
write-up on how I got `ptpd2` working as a receiver/client/slave (which besides
the installation, turned out to be very straightforward).


# Installing `ptpd2` via `ports`

`ptpd2` is not available as a binary package at the time of writing, so it needs
to be installed via ports. I have been solely using `pkg` for installing
packages, so I first needed to get set up to build `ports`. This is mostly based
on the [FreeBSD Documentation](https://docs.freebsd.org/en/books/handbook/ports/#ports-poudriere)
on setting up and using `poudriere`.

NOTE: This is not necessarily following "best practices" for dealing with ports
on a system that primarily uses binary packages. This is just how I managed to
get it to work. I would recommend reading the
[official documentation](https://docs.freebsd.org/en/books/handbook/ports/) if
you plan to follow this.

Install `poudriere`:
```sh
pkg install poudriere
```

The config for `poudriere` is located at `/usr/local/etc/poudriere.conf`. I
already use ZFS, so I decided to enable its use in `poudriere` by uncommenting
this line:
```
ZPOOL=zroot
```

I didn't want to bother looking for other mirrors, so I also used the suggested one:
```
FREEBSD_HOST=https://download.FreeBSD.org
```

I left the rest of the config as-is.

Create jail for `poudriere` to use (replace release version with whatever you
are running):

```sh
poudriere jail -c -j pjail-amd64-15_0 -v 15.0-RELEASE
```

Pull ports (if not using `latest`, you may prefer to use one of the quarterly
branches instead):
```sh
poudriere ports -c -m git+https
```

I ran the following to see what options were available for `ptpd2`:
```sh
poudriere options -j pjail-amd64-15_0 -c net/ptpd2
```

I disabled SNMP, as I was not planning on using SNMP to monitor it. I also
disabled DOCS for all the build dependencies, since I would not be installing
those packages on the host anyway.

I then created a file named `portlist-ptp` (the name doesn't really matter) that
contained the port I wanted to build:
```
net/ptpd2
```

Then used `poudriere` to build the ports in that file:
```sh
mkdir /usr/ports/distfiles
poudriere bulk -j pjail-amd64-15_0 -f portlist-ptp
```

I tried to use `poudriere`'s support for downloading binary packages when it
could, but after working around some bugs, it would refuse to use `pkg` even if
I used the right repo such that the version matched. This might be fixed in the
next release. Or I might have just been doing something dumb. Not a big deal as
this package only had 9 dependencies for the build, but it would have sped up
the build process.

After building, the resultant package is in `/usr/local/poudriere/data/packages/pjail-amd64-15_0-default/All/`,
and can be installed using:

```
pkg add /usr/local/poudriere/data/packages/pjail-amd64-15_0-default/All/ptpd2-2.3.1_2.pkg
```

# Setting up `ptpd2`

The service installed by `ptpd2` expects the config to be located at
`/usr/local/etc/ptpd2/ptpd2.conf`, or specified by `ptpd2_configfile` in
`rc.conf`. I used the `client-e2e-socket.conf.sample` file as a base, modifying
the following options:
 * `ptpengine:interface`: Changed to the proper interface on my machine (`ql0`)
 * `ptpengine:ip_mode`: Changed to `hybrid`
 * Replaced instances of `/usr/scratch/log` with `/var/log`
 * `global:quality_file_max_size`: Set to 1024 (1 MiB)
 * `global:quality_file_truncate`: Set to `Y`
 * `global:status_update_interval`: Increased to 30 seconds
 * `global:log_file_max_size`: Set to 16384 (16 MiB)
 * `global:log_file_truncate`: Set to `Y`
 * `global:statistics_log_interval`: Increased to 30 seconds
 * `global:statistics_file_max_size`: Set to 16384 (16 MiB)
 * `global:statistics_file_truncate`: Set to `Y`

I then disabled `ntpd` and enabled `ptpd2`:
```sh
service ntpd stop
service ntpd disable
service ptpd2 enable
service ptpd2 start
```

After that, it just worked. From `/var/log/ptpd2.status.log`:
```
Host info          :  shulgin, PID 97033
Local time         :  Fri Feb 13 18:31:17 CST 2026
Kernel time        :  Sat Feb 14 00:31:17 UTC 2026
Interface          :  ql0
Preset             :  slaveonly
Transport          :  ipv4, multicast
Delay mechanism    :  E2E
Sync mode          :  ONE_STEP
PTP domain         :  0
Port state         :  PTP_SLAVE
Local port ID      :  a0481cfffee079a8(unknown)/1
Best master ID     :  3ce4b0fffec7abc2(unknown)/1
Best master IP     :  10.0.0.20
GM priority        :  Priority1 1, Priority2 1, clockClass 6
Time properties    :  PTP timescale, tracbl: time Y, freq Y, src: GPS(0x20)
UTC properties     :  UTC valid: Y, UTC offset: 37
Offset from Master : -0.000002921 s, mean -0.000000883 s, dev  0.000006787 s
Mean Path Delay    :  0.000067972 s, mean  0.000066930 s, dev  0.000000202 s
Clock status       :  in control
Clock correction   : -0.849 ppm, mean -0.835 ppm, dev  0.006 ppm
Message rates      :  2/s sync, 2/s delay, 1/2s announce
TimingService      :  current PTP0, best PTP0, pref PTP0
TimingServices     :  total 1, avail 1, oper 1, idle 0, in_ctrl 1
Performance        :  Message RX 25/s, TX 1/s
Announce received  :  105
Sync received      :  417
DelayReq sent      :  425
DelayResp received :  425
State transitions  :  3
PTP Engine resets  :  1
```

# Tracking PTP statistics with Telegraf

I use Telegraf and InfluxDB to monitor my servers, and already have my Linux
machines reporting PTP statistics in. The statistics gathered make `ptpd2`
somewhat incompatible with those from `ptp4l`, so I'll need to create new
visualizations in Grafana, but not a big deal.

`/var/log/ptpd.log` contains the statistics I am after. The first line of the
file is a header for the CSV-formatted data that follows, so we know the fields:
```
# Timestamp, State, Clock ID, One Way Delay, Offset From Master, Slave to Master, Master to Slave, Observed Drift, Last packet Received, Sequence ID, One Way Delay Mean, One Way Delay Std Dev, Offset From Master Mean, Offset From Master Std Dev, Observed Drift Mean, Observed Drift Std Dev, raw delayMS, raw delaySM
2026-02-13 18:27:47.299886, init, 
2026-02-13 18:27:47.400574, lstn_init,  1 
2026-02-13 18:27:49.355197, slv, 3ce4b0fffec7abc2(unknown)/1,  0.000000000,  0.000000000,  0.000000000,  0.000000000, -79.605102539, I, 03911, 0.000000000, 0, 0.000000000, 0, 0, 0,  0.000000000,  0.000000000
...
2026-02-13 19:22:50.238305, slv, 3ce4b0fffec7abc2(unknown)/1,  0.000072714,  0.000008748,  0.000071833,  0.000092066, -953.521102539, D, 06565, 0.000072590, 62, 0.000000301, 4067, -959, 2,  0.000092066,  0.000075741
```

I'm not going to go into detail about the config, but in the end this is what I
ended up with for the Telegraf input config:

```toml
# PTP statistics
[[inputs.tail]]
  name_override = "ptpd2"

  files = ["/var/log/ptpd.log"]

  data_format = "csv"

  csv_trim_space = true

  csv_column_names = ["time",   "state",  "clock_id", "ign_0", "off",   "ign_1", "ign_2", "drift", "ign_3",  "ign_4", "owd_mean", "owd_stddev", "off_mean", "off_stddev", "drift_mean", "drift_stddev", "ign_5", "ign_6"]
  csv_column_types = ["string", "string", "string",   "float", "float", "float", "float", "float", "string", "int",   "float",    "int",        "float",    "int",        "int",        "int",          "float", "float"]

  fieldexclude = ["time", "state", "clock_id", "ign_*"]
```

I could have probably gotten Telegraf to parse the time column as well, but I'm
fine with it just treating it as the current time of the machine, so I didn't
bother.
