---
layout: post
title:  "Keithley 615 Electrometer Interface - Part 2: Testing replacement PCBs, and designing interface PCB"
date:   2026-03-23 18:00:00 -0500
categories: test-equipment
permalink: /posts/keithley_615_electrometer_interface_part_2.html
---

Well, it's been over two years from the [last post](/posts/keithley_615_electrometer_interface_part_1.html),
but I guess better late than never.

# Replacement Boards

<table>
  <colgroup>
    <col width="25%"/>
    <col width="25%"/>
    <col width="25%"/>
  </colgroup>
  <thead>
    <tr class="header">
      <th>Board</th>
      <th>Front</th>
      <th>Rear</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>PC209 v1.0</td>
      <td><img src="/assets/posts/20260323_kei_part2/pc209v1.0_front.jpg" alt="PC209 v1.0 front"/></td>
      <td><img src="/assets/posts/20260323_kei_part2/pc209v1.0_rear.jpg" alt="PC209 v1.0 rear"/></td>
    </tr>
    <tr>
      <td>PC218 v1.0</td>
      <td><img src="/assets/posts/20260323_kei_part2/pc218v1.0_front.jpg" alt="PC218 v1.0 front"/></td>
      <td><img src="/assets/posts/20260323_kei_part2/pc218v1.0_rear.jpg" alt="PC218 v1.0 rear"/></td>
    </tr>
    <tr>
      <td>PC218 v2.0</td>
      <td><img src="/assets/posts/20260323_kei_part2/pc218v2.0_front.jpg" alt="PC218 v2.0 front"/></td>
      <td><img src="/assets/posts/20260323_kei_part2/pc218v2.0_rear.jpg" alt="PC218 v2.0 rear"/></td>
    </tr>
    <tr>
      <td>PC218 v2.2</td>
      <td><img src="/assets/posts/20260323_kei_part2/pc218v2.2_front.jpg" alt="PC218 v2.2 front"/></td>
      <td><img src="/assets/posts/20260323_kei_part2/pc218v2.2_rear.jpg" alt="PC218 v2.2 rear"/></td>
    </tr>
  </tbody>
</table>

In order to make insertion of the boards into the slots easier, I sanded a small
chamfer onto the edge that inserts into them.

## Testing

<img src="/assets/posts/20260323_kei_part2/installed_boards.jpg" alt="PC209 and PC218 installed in the 615" width="33%"/>

(I had originally planned on creating a bracket to hold these boards in place
using that post between them, but these boards are such a tight fit that it is
unnecessary.)

### PC209 (Output buffers and print delay)

Delay measurement | Pulse width measurement
:---:|:---:
![PC209 delay measurement](/assets/posts/20260323_kei_part2/pc209_scope_delay.png) | ![PC209 pulse width measurement](/assets/posts/20260323_kei_part2/pc209_scope_pulsewidth.png)

Testing the timing on PC209, the values all look reasonable. The delay between
the sample trigger and the start of the pulse is ~9.7 us. The pulse width is
~235 us - the manual specifies 100 us, but the simulation of the schematic
showed a value of ~250 us, so it is close enough, and longer times are safer
than shorter.

I did also need to remove R31, as it was causing the input to the sensitivity
2x10^0 buffer to be pulled too low to be treated as logic high. Since the Print B
command that this resistor feeds into the logic for is completely unused in the
615 (based on the schematics at least), I didn't bother fixing it properly.


### Buffer outputs

<img src="/assets/posts/20260323_kei_part2/test_board_in_use.jpg" alt="Interface test board connected to 615" width="33%"/>

In order to test the buffer outputs and the pinout, and before finalizing the
interface board, I created a small breakout board so I could test the output
voltages, and make sure everything was working properly. It also includes LEDs
to more easily observe the output without probing each point.

I had originally intended to have the connector on the top of the board, but I
messed up the pin numbering. Thankfully, it was messed up in a way that I could
just install the connector on the other side of the board instead (if only I had
realized that _before_ installing it on the top side first). Definitely glad I
caught that before finalizing the interface board design.

Both versions of the PC218 replacement worked fine, as did the few buffers
present on the PC209 replacement. Since they both worked, I decided to move
forward with the simpler v2 variant with the 4010 output buffers (as mentioned
in the previous post, this won't be a 1-to-1 match with the original behaviour,
but it shouldn't matter for any modern applications). I ended up re-designing
the PCB to be the same size as the PC209 board, along with moving the silkscreen
to the same side of the board and adding some voltage test points.


# Interface board design

With the replacement board working and the issue with the connector figured out,
I could finalize the design for the interface board.

I wanted to maximize my options for how I could interface with this board, so I
added support for USB (with options to route it directly to the MCU, or via an
FTDI USB-UART chip), RS-232, and Ethernet (via a Wiznet W5500). Based on the I/O
requirements, I chose the STM32G0B1RET for the MCU.

The board can be powered from the 615 interface itself, via USB, or via an
external source. I added all those options mainly because I was not sure if the
615 could supply the necessary power to the board. It turns out this probably
wasn't a concern, but may still be useful if the noise from the digital
circuitry on the interface board could mess with very sensitive measurements -
especially since I am using a switch-mode power supply (based on the Diodes
Incorporated AP62250).

For the buffer outputs from the 615, I used voltage dividers to bring down the
15 V logic levels down to a level that the STM32 could handle. The values were
chosen so that it would work both with the v2 output buffers (with very low
output impedance), and the v1 buffers (which have a 3.9k output impedance). For
the inputs to the 615 (Hold 1, Hold 2, and Trigger), these are simply NPN
transistors that pull the lines to ground.

Overall, the design is unremarkable. As with the other boards, the schematics
can be found [here](https://git.pfarley.dev/pfarley/keithley-615-printer-boards).

<table>
  <colgroup>
    <col width="25%"/>
    <col width="25%"/>
  </colgroup>
  <thead>
    <tr class="header">
      <th>Front</th>
      <th>Rear</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><img src="/assets/posts/20260323_kei_part2/interface_front.jpg" alt="Interface board front" width="50%"/></td>
      <td><img src="/assets/posts/20260323_kei_part2/interface_rear.jpg" alt="Interface board rear" width="50%"/></td>
    </tr>
  </tbody>
</table>

(Yes, one of the resistors in the interface section is upside down, it bugs me
too, but not enough to fix it)

During the initial testing of the board, I discovered that I had an off-by-one
error in the connections for the W5500 SPI bus, so I had to make some small
bodges to fix that and move one of the interface input lines, as can be seen in
the above picture. Last time I tested the board, I was unable to get USB working
directly with the STM32. I have since gotten this working with another board I
am working on with the same chip, so I probably just need to double-check my
routing and firmware. Other than that, everything seems to be working so far.

# Interface board firmware, future
The current state of the firmware can be found
[here](https://git.pfarley.dev/pfarley/keithley-615-net-fw).

For the firmware, I have been using Zephyr. This has made it really easy to get
Ethernet working, as it already has a driver for the W5500, and a full network
stack. Same should apply to USB (as it has for another project) once I get that
working properly.

The interface portion appears to be working properly. The driver itself I
wouldn't say is "properly" written - this was my first use of Zephyr, and I just
relied on GPIO definitions in the user section of the device tree. I have since
written more drivers for other projects, and would like to re-write this at some
point to be implemented more like a traditional Zephyr driver. But as it stands,
it can read the signals from the 615 when it sees a print signal, and combine
the various BCD values into an actual reading. One limitation is that the 615
does not actually tell the device what mode it is in (voltage, current,
resistance, or charge), so that needs to be supplied in order for it to know the
correct sign of the exponent (voltage has no exponent, resistance is positive,
and current and charge are negative), and to append the unit.

My goal is for this to be able to support two things:
* Standard SCPI command interface, with integration into [`testeq-rs`](https://git.pfarley.dev/pfarley/testeq-rs)
  * Plain SCPI commands via serial
  * Either SCPI commands over CDC ACM, or SCPI over USBTMC, via USB
  * SCPI over VXI-11 via Ethernet
* Long(-ish) term data logging
  * Could be via SCPI, or another mode that just continuously outputs readings
    as it receives them.

I already haven't touched this thing in over two years, so we'll see when or if
I ever get to that. Now that I have an actual modern network-connected DMM, this
doesn't have the same immediate usefulness to me, unless I need to measure very
small currents or charges, or very large resistances, and those measurements
would benefit from data logging or automated test setups.

