---
layout: post
title:  "Writing BDM Interface for the Glasgow Interface Explorer"
date:   2024-10-15 21:00:00 -0500
permalink: /posts/writing_bdm_interface_for_glasgow.html
categories: fpga glasgow microcontroller
---

As I've been working on reverse-engineering the SDR module from the Sigfox base
station, I also wanted to dump any ROMs from the device. The audio interface
chip was easy, since it had an external SPI flash that could be dumped with
`flashrom` or another tool. The microcontroller on the board was less
straightforward, however. It was a Freescale HCS08 which didn't use an
industry-standard debug interface like JTAG or SWD, but rather a custom protocol
called Background Debug Mode (BDM) interface. I couldn't find any
readily-available software to communicate with this using FTDI chips or anything
else (apart from [this project](https://github.com/Najsztub/BDM_UsbBlaster/)
which implemented it using an STM32, which I didn't try).
I also recently got a Glasgow Interface Explorer, so I thought this might be a
good opportunity to learn how to use it. While I wasn't even sure if the chip
might be locked, I would at least learn something even if it failed.

# Glasgow Interface Explorer

The [Glasgow Interface Explorer](https://glasgow-embedded.org) (I'll refer to it
as simply the Glasgow from now on) is a tool designed to make working with
digital protocols (relatively) easy. It contains an FPGA with 16
externally-accessible I/O (with two configurable voltage domains), and a USB
interface to facilitate communication with software running on a computer (in
the standard Glasgow software ecosystem this is Python code). This allows you
to implement timing-critical communication details in the FPGA, and everything
else in the user app.

The FPGA gateware is written in Python using [Amaranth](https://github.com/amaranth-lang/amaranth),
rather than something more traditional like Verilog or VHDL, and it provides
some features that integrate well with the app side of things, like FIFOs. I've
written very little gateware up to now, mostly just in college and later when
tinkering with a single-instruction CPU design - both using Verilog. Amaranth is
quite a bit different (ignoring the obvious syntactic difference of using Python
as a base) from Verilog, so it has been a bit of a learning curve (and I'm still
not all that experienced with it, or Verilog for that matter), but I'm starting
to appreciate it more the more I use it. And this is coming from someone who
isn't a huge fan of Python.

# Adding an applet to the `glasgow` tool

The standard interface to the Glasgow is the [glasgow](https://github.com/GlasgowEmbedded/glasgow)
tool. There are several protocols built-in to this tool, such as UART, I2C, JTAG,
among others. There is also some additional support for devices that use these
protocols, that build on top of the base protocols. At the time of writing, there is no
_official_ support for using out-of-tree gateware and applets (the term for the
app that runs on the host, rather than the FPGA) - though there is
[experimental support](https://github.com/GlasgowEmbedded/glasgow/tree/main/examples/out_of_tree)
for loading them. Due to this, I decided to create this BDM interface in a fork
of `glasgow` - even though I don't think it will be of high enough quality to
submit a PR (I'm just implementing the bare-minimum to try to dump the chip, and
don't have any other hardware to test some of the other BDM functionality, such
as writing, on).

Since the documentation for how to add applets to the tool is currently a little
lacking, I decided to write a bit about how to add an applet and gateware into
the `glasgow` tool. Once out-of-tree applets are fully supported, I would
probably recommend going that route instead unless you were intending to
upstream any changes.

Adding gateware is pretty simple. It doesn't actually _need_ to be in a specific
location, it can even exist in the applets themselves (many of which do include
small pieces of gateware that help to interface with the common gateware code,
or to add more functionality). But if it has some core support that can be
useful in multiple applets, it (from my observation) should exist in
`software/glasgow/gateware/`. These can then be included in the applets as you
would any other Python code.

Adding applets requires a little more work, but is straightforward once you find
out what you need to do. The applets themselves would go under
`software/glasgow/applet/...`, the sub-directories depending on the specific
thing the applet is doing/working with. But adding it there is not sufficient:
you also need to add a reference it to `software/pyproject.toml` in the form of:

```
<applet name> = "<dotted applet path>:<applet class>"
```

After which, if you reload `glasgow` (`pipx upgrade glasgow`), it should show up
in `glasgow run --help`.

# The BDM protocol

Most of this information I obtained from the datasheet for the MC9S08G
datasheet, and from experimentation.

The BDM protocol uses only a single signal - called BKGD or Background - for
bi-directional communication. The pin is used as what Freescale calls a
"pseudo-open-drain" - the target has an internal weak pull-up, but allows for
sending "speed-up" high pulses to allow faster communication in the presence of
capacitance. The communication is completely controlled by the host - if it
wants to read data from the target, it needs to "request" every bit with a low
pulse. Data is is sent most-significant-bit first.

{% wavedrom %}
{
 signal: [
   {name: 'clk', wave: 'n..|....|....|....', period: 1},
   {node : ".E....F....G....H"},
   {name: 'bkgd', wave: '10.|..1.|..0.|..1.', data: ["Host drives high for a 1"]}
 ],
 "edge": [
   "E+F Host drives low >= 128 cycles",
   "F+G Target waits 16 cycles",
   "G+H Target pulls low 128 cycles"
 ]
}
{% endwavedrom %}

Before communicating with the target, the host needs to know the clock rate the
host is using for communication. To determine this, there is a special "sync"
command that allows deriving the clock rate from a pulse width. To perform this,
this host first pulls BKGD low for at least 128 clock cycles of the slowest
possible clock the target may be using. After that it delivers a "speed-up"
pulse to return the line to a high state. Once it sees BKGD go high, the target
will wait for 16 cycles, then pull it low for 128 clock cycles, before delivering
a "speed-up" pulse. The host can then determine the clock rate based on the
width of that low pulse.

{% wavedrom %}
{
 signal: [
   {name: 'clk', wave: 'n.................', period: 1},
   {node : ".A.........B.."},
   {node : ".C...............D."},
   {name: 'bkgd', wave: '10...=.......1...0', data: "bit"}
 ],
 "edge": [
   "A+B 10 cycles before read",
   "C+D 16 cycles - min bit time",
 ]
}
{% endwavedrom %}

To write a bit to the target, the host first pulls BKGD low for 4 clock cycles,
then if it is writing a 0, it will continue pulling low for another ~9 cycles,
and if it is writing a 1, it will pull high and it will remain high for ~12 more
cycles. The target will read the bit 10 cycles after the host first pulled the
line low, and the host must wait at least 16 cycles before transmitting another.

{% wavedrom %}
{
 signal: [
   {name: 'clk', wave: 'n.................', period: 1},
   {node : ".E...F........"},
   {node : ".A.........B.."},
   {node : ".C...............D."},
   {name: 'bkgd', wave: '10...z..=....1...0', data: ["Target drives high for a 1"]}
 ],
 "edge": [
   "A+B 10 cycles before read",
   "C+D 16 cycles - min bit time",
   "E+F Host drives low",
 ]
}
{% endwavedrom %}

To read a bit from the target, the host will still pull BKGD low for 4 clock
cycles, then it will release the line. If the target is sending a 1, it will
pull the line high 3 pulses later, else it will wait 9 cycles. The host will
read the bit value 10 cycles after it first pulled the line low.

# The implementation

The implementation can be found in
[this commit](https://github.com/GlasgowEmbedded/glasgow/commit/da739abb39c6bab254edd1ed7ddf98242cb84a40).

NOTE: At the time of writing, this is still a fairly "hacky" implementation - if
I were to need to do more with this, or if I wanted to upstream it, I would
definitely need to refactor some things. Both in making the gateware cleaner and
better structured, and making the applet more flexible and general.

There are a number of commands supported by the MC9S08GB32ACFBE that I am
targeting, but I really only care about one - `READ_BYTE` - who's name is
pretty self explanatory. It consists of sending `E0`, followed by the 16-bit
address to read from, then waiting 16 clock cycles, then reading back the
8-bit value stored at that address.

Even though I only wanted to support the two commands (`SYNC` and `READ_BYTE`),
I still wanted to make the gateware as flexible as possible - both for future
expansion, and to make testing quicker (if I make changes to the gateware,
`glasgow` needs to re-flash the FPGA, but if I only make changes to the applet
(in a way that doesn't impact the generated gateware) it can run essentially
immediately). To do this, I made the transaction between the host and the
gateware look like this:

 * Host sends flags byte
   * Bit 0: Delay 16 cycles after write
   * Bits 1-7: Reserved
 * Host sends number of bytes it intends to write
 * Host sends the data to write
 * Host sends the number of bytes to read
 * FPGA sends the read bytes

Based on the datasheet, all commands (besides the special `SYNC` "command")
will always consist of writing bytes, a possible delay, and a possible read
of bytes, always in that order. So this should cover any command.
The FPGA also has support for the `SYNC` command, and will perform that once
when it starts, unless a specific clock rate is defined. All commands after the
initial startup will use the derived or specified clock rate.

It also has really basic support of the reset pin - if it is specified, it will
reset the target at the beginning, and will hold `BKGD` low for a period after
the reset to attempt to force the target into background mode. Ideally it would
support _not_ resetting the target even when the pin is specified - it could be
useful to be able to reset the target after a given command, and be able to
control whether it resets into regular or background mode. Perhaps if I ever
have a need to actually program/debug one of these chips, I'll add support for
that.

I'm not going to go into too much detail here, since there aren't really many
standalone code snippets that will be useful, and you can take a look at the
above linked commit to see the whole thing (which isn't really too much). But
just some simple notes:
 * The `BDMBus` class in the gateware abstracts some of the details of how the
   FPGA deals with the BKGD and reset pins, making the bulk of the code simpler
 * The bulk of the implementation is in the `BDM` class
 * The `__init__` methods of each class just set up some data in the object to
   be used later, with just a little math and other logic to make things easier
   later on.
 * The `elaborate` methods generate the actual gateware (perhaps an over-simplification)
   * Adding operations to `m.d.comb` will make them always happen immediately
   * Adding operations to `m.d.sync` will make them take effect on the next clock
   * When something is within a `with m.{State,If,Elif,Else,etc...}:` block,
     that will create conditional logic (I'm sure there is a better term) within
     the gateware
 * Some documentation can be found [here](https://amaranth-lang.org/docs/amaranth/latest/intro.html)

On the applet side, currently it is just hard-coded to read a string of bytes
from the target. For reasons you will see in the next section, I didn't bother
making it too general or usable.

# Results

<img src="/assets/posts/20241015_glasgow_bdm/glasgow_sdr_debug.jpg" alt="Glasgow wired up to Sigfox SDR" width="45%"/>

After all the above... it didn't work. The BDM implementation was almost
certainly _working_, it replied as expected to commands and I was able to derive
the clock from the `SYNC` command, it just didn't return useful data in the
`READ_BYTE` command. The target was definitely responding with data, it wasn't
always zeroes or ones, but it always responded with either `0xFF`, or `0x00`,
nothing else. I suspect this is just the behavior when the chip is locked, I
just would have expected all zeroes or all ones instead. I could be overlooking
something though.

But, it was still a useful project to learn how the Glasgow works even if it
didn't get the results I wanted. And if I ever need to do more with a
BDM-supporting chip in the future, I have a starting point now.


