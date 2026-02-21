---
layout: post
title:  "Using Linux device-tree with PCIe devices"
date:   2024-02-20 17:45:00 -0600
categories: linux
permalink: /posts/using_linux_device_tree_with_pcie_devices.html
---

Back in 2015, [Linux deprecated the `/sys/class/gpio` interface](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/Documentation/ABI/obsolete/sysfs-gpio?h=v5.16&id=fe95046e960b4b76e73dc1486955d93f47276134)
in favor of using other methods to access GPIO pins. It's been over 8 years
since then, and the interface is still around, and thus some systems still make
use of it. Many of these are fairly easy to change to use pre-existing drivers
suck as `gpio-leds` or `gpio-keys`, at least on systems that use device-tree.
Other use cases can be solved by creating a simple custom driver or extending an
existing one. One area that is a bit less straight-forward is associating GPIOs
with a device on the PCIe bus. Typically, you don't define PCIe devices within
the device-tree, since they are dynamically discovered. And this doesn't just
apply to associating GPIO pins, but with associating any type of device or data
to a PCIe device.

I tried looking online for any documentation on doing this, but it seems that
it's a relatively uncommon need. Most posts/questions/articles I could find
on the subject seemed to be about setting up the PCIe ports (root complex ports?)
that are directly on an SoC. In my case, this much was already done, and these are
commonly provided by the vendor (though in some instances they may need to be
modified) if the SoC has good support. I was able to find
[one Stack Overflow question](https://stackoverflow.com/questions/54367498/creating-a-device-tree-for-the-hardware-on-a-pci-device)
that gave me some clues on how to go about it. I was also able to find a little
more in the kernel documentation, but again most of that was about setting up
root ports/bridges.

Initially, I more-or-less got it working on some devices through
trial-and-error. I always just kept the `regs` values as all zeros, and didn't include
the `ranges` values. On these devices, it was a lot simpler since the PCIe
devices were connected directly to the SoC. In the end, I was able to get away
with something similar to the following:

```
&pcie0 { /* Typically defined in a dtsi for the SoC */
    status = "okay";

    pcie@0,0 { /* PCIe bridge/root */
        #address-cells = <3>;
        #size-cells    = <2>;
        reg = <0 0 0 0 0>;

        device_name: pcie@0 {
            compatible = "pci<vendor ID>,<device ID>";

            reg = <0 0 0 0 0>;

            /* Your stuff goes here */
        }
    }
}
```

And this worked great for those simpler devices, but it was not sufficient if
one of the PCIe devies was behind a PCIe switch. I attempted to get it working
through dumb trial-and-error again, but this time I wasn't having any luck.
I went through `/sys/bus/pci/devices` to find the hierarchy, which got me
a good bit of the way there, but the driver still was not picking up the entries.

Eventually I remembered seeing [this LKML patch](https://lwn.net/Articles/917999/)
that I had initially dismissed as I didn't fully read it and didn't know it
was in mainline and usable on our platform. So I enabled the kernel config
option (`PCI_DYNAMIC_OF_NODES` - Create Device tree nodes for PCI devices)
and loaded the new kernel on my device. At first, this didn't
fully work - it seems that it doesn't always fully auto-generate the entries
if there are any conflicting entries in the device-tree. So I temporarily
removed those entries, and then it fully generated the PCIe device-tree
(apart from the devices). In order to read it in a sensible way, I copied
the contents of `/sys/firmware/devicetree` to my computer, and used `dtc`
to convert it into `dts` format (`dtc -I fs -O dts <path> > tree.dts`).

At this point, I just tried replicating the same structure it had. I think
the most important part I was missing was proper values for the `reg` field.
The first bridge has them as all zeros, so it makes sense that that also
worked for me. But the switch/nested bridges had non-zero values for these.
After adding those, it still wasn't working correctly. After adding some
debug prints to show which items in the PCIe hierarchy properly picked up
fwnode items, I realized that it was trying to use another node I hadn't moved
yet for one of the bridges, and not the node that actually had the device as
a child. (My current guess is that for bridges where they are alone at the
same location in the hierarchy, a `reg` of all zeros will work, but it might
not if the bridge has neighbors at the same level, or if it's device ID is not
zero. I'm just glad to have gotten it working, and don't really feel like
trying a bunch of permutations to figure out all the rules.)

So in the end, I ended up with a device-tree closer to this:

```
&pcie0 {
    status = "okay";

    pcie@0,0 { /* Root */
        #address-cells = <3>;
        #size-cells = <2>;
        reg = <0 0 0 0 0>;

        pcie@0,0 { /* Switch */
            #address-cells = <3>;
            #size-cells = <2>;
            reg = <0x10000 0x00 0x00 0x00 0x00>;

            pcie@1,0 { /* Switch */
                #address-cells = <3>;
                #size-cells = <2>;
                reg = <0x20800 0x00 0x00 0x00 0x00>;

                device_0: pcie@0 { /* Device */
                    compatible = "pci<pid>,<vid>";
                    reg = <0 0 0 0 0>;

                    /* Properties go here */
                };
            };

            pcie@3,0 { /* Switch */
                #address-cells = <3>;
                #size-cells = <2>;
                reg = <0x21800 0x00 0x00 0x00 0x00>;

                device_1: pcie@0 { /* Device */
                    compatible = "pci<pid>,<vid>";
                    reg = <0 0 0 0 0>;

                    /* Properties go here */
                };
            };
        };
    };
};

```

And in case it might be useful to anyone else, this is the code I used to
see what PCIe bus nodes were picking up fwnodes:

```c
strict pci_dev *dev;

...

struct pci_bus *p_bus = dev->bus;
while (p_bus && (p_bus->parent != p_bus)) {
    if (p_bus->dev.fwnode) {
        const char *name = fwnode_get_name(p_bus->dev.fwnode);
        dev_warn(&dev->dev, "PCI parent bus has fwnode: %s", name);
    } else {
        dev_warn(&dev->dev, "PCI parent bus has no fwnode");
    }

    p_bus = p_bus->parent;
}

if (dev->dev.fwnode) {
    const char *name = fwnode_get_name(dev->dev.fwnode);
    dev_warn(&dev->dev, "Device has fwnode: %s", name);
} else {
    dev_warn(&dev->dev, "Device has no fwnode");
}
```
