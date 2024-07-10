---
layout: post
title:  "Sigfox Base Station Reverse Engineering - Part 1: Overview"
date:   2024-07-09 21:00:00 -0500
categories: reverse-engineering rf sdr
---

Over a year ago I obtained a Sigfox base station, or TAP (Transfox Access Point),
from a company that was moving and wanted to get rid of some of their old
equipment. Sigfox operates a LPWAN (Low-Power Wide-Area Network), more-or-less
as a competitor to LTE Cat. M/NB-IoT or LoRaWAN. I don't think it ever acheived
widespread adoption (in my experience - admittedly US-centric with a little
experience in the UK and EU markets - Cat. M and NB-IoT have become more-or-less
the dominant technologies in this space, due to their wide availability), though
they are still around (since 2010) so must have had success in some markets.

< Insert front photo here, or perhaps later >

I've been wanting to reverse-engineer and potentially repurpose this hardware
for a while, but I haven't gotten to it until now. I haven't been able to find
much info at all on the internet about the TAP, aside from some FCC filings which
don't really contain much (Sigfox provided a Letter of Confidentiality to prevent
the FCC from publishing the schematics, block diagrams, operational descriptions,
and internal photos - I typically expect those first three to not be published,
but internal photos are more hit-or-miss).

Sidetracked: Older Sigfox products
----------------------------------

While looking into this Sigfox hardware, I stumbled upon some other products that
Sigfox used to sell, presumably before they started fully focusing on LPWAN. There
is very little info about these products around anymore. I first found out about
the Transfox SDR after looking for more info on the TAP (I found the acronym
defined in some FCC filing, if I recall) and found
[this product sheet](http://www.ea1ddo.es/Temp/TransFox.pdf). This in turn held
a mention of the SynFox synthesizer, which I found some more info about
[here](http://www.sigfox-system.com/pages/telechargementspag.html). I also found
[this page](http://www.ke5fx.com/synth.html) that mentioned the SynFox, and linked
to Sigfox's old website (sigfox-system.com).

sigfox-system.com is no longer around, and it was not well-preserved by the
Internet Archive. It seems like all of it's pages do not display properly - at
first I thought that the archive hadn't stored any real pages at all, they just
appeared blank. However, digging into the source I realized there was some actual
content there. For instance, [this page](https://web.archive.org/web/20080514153056/http://www.sigfox-system.com/pages/telechargementspag.html)
shows as blank (minus the Internet Archive toolbar), but if I look at the source
I do see the links. Unfortunately, all these links point to tera-concept.com, and
none of them are archived (presumable TERA CONCEPT developed/helped develop the
hardware/software for some of Sigfox's earlier products).

Their website was also peppered with Lorem Ipsum, so it was definitely in the
start-up stage.

It also shows existence of yet another Sigfox product, the BlueFox. Confusingly,
there is also a more recent device called the BlueFox by Net Sensors that _uses_
a Sigfox radio, but is seemingly unlreated to this original BlueFox. According
to [their webside](https://web.archive.org/web/20080409060130/http://www.sigfox-system.com/pages/bluefoxpag.html) (translated from French):

> “BlueFox” 2.4 GHz “long range” USB radio module.
> The BlueFox "long range" 2.4 GHz USB radio module, allowing robust data
> transmission at 1 Mbit/s, over distances of 100 m to 20 km depending on the
> installation.

[SynFox](https://web.archive.org/web/20080511140303/http://www.sigfox-system.com/pages/synfoxpag.html):

> SynFox: Coverage, precision, speed and low noise at a price never seen before!

There is also a [20W RF power amplifer](https://web.archive.org/web/20080409060208/http://www.sigfox-system.com/pages/pa20wpag.html),
and another [2-4W RF amplifer](https://web.archive.org/web/20080409060213/http://www.sigfox-system.com/pages/paldmospag.html).

Connectivity
------------

The device is mostly self-contained. It has two status LEDs on the front (status
and power), and a "service mode" button used for power control on the front.

< Include photo of rear >

Around back, there is an Ethernet jack for network connectivity, and another RJ45
for serial console (unsure if this is the standard Cisco-style pinout or not, as
I have just used the internal DE-9). Under that, there are two USB ports (one
intended use of which is connection a cellular modem), and the power input that
is fed by a semi-integrated power brick. On the other side, there is an N
connector that goes out to the antenna (and LNA and/or filter).

Inside
------

< Include photo of inside >

Inside the unit, we find that it is all powered by a standard x86 computer. There
is a custom board for power and some I/O, and two enclosed RF units. One is
connected to the PC via USB, and one is connected via a ribbon cable to the
power/I/O board.

Motherboard
-----------

< Include photo of motherboard, and CPU + RAM >

The motherboard is a fairly standard (mini ITX???????) board, with an intel i3 3220T
(a low-TDP/low-clock variant of a 3220), and 2 GiB DDR3 RAM.

< Include photos of USB stick >

The OS is stored on an ATP USB drive intended for high-relibility and industrial
applications. The device is simply running Linux < insert version here >.

< Include photos of PicoPSU >

The motherboard is powered by a PicoPSU, which is in turn connected to the custom
power board.

BRE: Power and I/O board
------------------------

RF modules
----------

< Include photo of the RF modules >

I will save the RF modules for another time, a I want to go much more in-depth
on them. For now, I will say the one near the front (with the heat warning) is
an SDR (based partially on a USB audio interface). The other modules is a power
amplifier.

LNA, Filter, and Antenna
------------------------

< Inclue photo of the LNA and cavity filter >

TODO
