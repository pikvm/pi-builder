# pi-builder

pi-builder is an easy-to-use and extendable tool to build [Arch Linux ARM](https://archlinuxarm.org) for Raspberry Pi using [Docker](https://www.docker.com).

-----
# Challenge
To build an OS, developers usually use a set of shell scripts, unique for each distribution. Those scripts create a chroot with necessary packages, edit configs, add users and so on. As a result, the system has the bare minimum to load, run and be further customised by the user.

However, when you create a product based on a single-board machine (a small router, an IP-camera, a smart home controller, etc), you might want to log all changes you made to the fresh OS to be able to repeat them without forgetting an important step like setting up `sysctl`.

A common solution is to create a large and horrifying shell script that executes all necessary actions either on the dev machine or the device itself. In case you use  `chroot` and [binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc) or need to save intermediate changes, script complexity grows exponentially and it quickly becomes impossible to support.

-----
# What is pi-builder?
It's a new approach to target OS building on embedded devices. With pi-builder, you can build an image as if it was a simple Docker container rather than a real-world device OS. The build process is described using the default [docker file](https://docs.docker.com/engine/reference/builder) syntax and it's executed in Docker on your dev machine. The resulting image can be exported to the SD card and loaded directly to Raspberry Pi.

-----
# Why pi-builder?
* **Builds are documented and repeatable**. A docker file is virtually ready documentation listing steps needed to set up the whole system.
* **Simplicity**. Seriously, what can be easier than writing a docker file?
* **Speed and build caching**. Target OS building can consist of hundreds of complicated and long steps. Thanks to Docker and its caching you won't run all of them each time you build a new OS; execution will start from whatever command was changed, taking previous results from cache.
* **Real environment testing**. When you're developing software that will run on Raspberry Pi it makes sense to test it using the same environment to avoid future problems.

-----
# How does it work?
Arch Linux ARM (and other systems as well) comes in form of a [minimal root file system](https://mirror.yandex.ru/archlinux-arm/os/) you can install on and run from a flash drive. As those are regular roots, you can use them to create your own base Docker image using [FROM scratch](https://docs.docker.com/develop/develop-images/baseimages). This image, however, will contain executables and libraries for the `ARM` architecture, and if your machine is, eg., `x86_64`, none of the commands in this image will run.

The Linux kernel, however, has a special way to run binaries on a different architecture. You can configure [binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc) to run ARM binaries using an emulator (in this case, `qemu-arm-static` for `x86_64` ). Pi-builder has a [small script](https://github.com/pikvm/pi-builder/blob/master/toolbox/install-binfmt) that sets up binfmt_misc on the host system to run ARM files.

In pi-builder, OS building is separated into **_stages_**, each of them being a different element of OS configuration. For example, the [ro](https://github.com/pikvm/pi-builder/tree/master/stages/arch/ro) stage includes `Dockerfile.part` with all the necessary instructions and configs to create a read-only root. A [watchdog](https://github.com/pikvm/pi-builder/tree/master/stages/arch/watchdog) stage has everything needed to set up a watchdog with optimal parameters on Raspberry Pi.

A full list of stages that come with pi-builder can be found [here](https://github.com/pikvm/pi-builder/tree/master/stages) or below. You can choose the stages you need to set up your system and include them in your config. Stages are basically pieces of docker file that are combined in a specific order and executed during the build. You can also create your own stages by analogy.

Build sequence:
1. pi-builder downloads statically compiled Debian `qemu-arm-static` and sets up `binfmt_misc` globally on your machine.
2. The Arch Linux ARM image is downloaded and loaded into Docker as a base image.
3. The container is build using the necessary stages -- package installation, configuration, cleanup, etc. 
4. You can run `docker run` (or `make shell`) in the resulting container to make sure everything's fine.
5. Pi-builder's utility [docker-extract](https://github.com/pikvm/pi-builder/blob/master/toolbox/docker-extract) extracts the container from Docker's internal storage and moves to the directory, making it an ordinary root file system.
6. You can copy the resulting file system to the SD card and use it to load Raspberry Pi.

-----
# Usage
To build with pi-builder you need a fresh Docker that can run [privileged containers](https://docs.docker.com/engine/reference/commandline/run/#full-container-capabilities---privileged) (needed by [auxilary image](https://github.com/pikvm/pi-builder/blob/master/toolbox/Dockerfile.root) to install `binfmt_misc`, format the SD card and some other operations).

Pi-builder is configured by the main [Makefile](https://github.com/pikvm/pi-builder/blob/master/Makefile) in the repository root. You can change parameters in the beginning, to do so create a file `config.mk` with new values. Default values are:

```Makefile
# Temporary images namespace, call in whatever you like
PROJECT ?= common

# Target Raspberry Pi platform
BOARD ?= rpi4

# List of necessary stages, more on it below
STAGES ?= __init__ os pikvm-repo watchdog no-bluetooth no-audit ro ssh-keygen __cleanup__

# Target system hostname
HOSTNAME ?= pi

# Target system locale (UTF-8)
LOCALE ?= en_US

# Target system timezone
TIMEZONE ?= Europe/Moscow

# Memory card location
CARD ?= /dev/mmcblk0
```

The most important parameters are `BOARD` (which board should the system be built for), `STAGES` (which stages should be included) and `CARD` (the SD card directory). You can change them by either passing new parameters when you run `make`, or by creating a `config.mk` with new values.

The `__init__` stage must always be first: it has init instructions to create the base system image (`FROM scratch`). Stages that follow make the system "feel like home" -- by installing useful packages, setting up watchdog, making the system read-only, setting up root SSH keys and cleaning up temp files.

You can create your own stages and add them to the build alongside stock ones. To do so, create a directory for your stage in the `stages` folder and place the `Dockerfile.part` file there, similar to other stages. Alternatively, you can follow the same path as [Pi-KVM](https://github.com/pikvm/os) (which was the first project pi-builder was made for).

-----
# Stock stages
* `__init__` - the main stage that creates the base image based on root FS Arch Linux ARM. It should ALWAYS come first in the `STAGES` list. 
* `os` - installs some packages and sets the system up a bit to make it more comfortable. You can [check what's inside](https://github.com/pikvm/pi-builder/tree/master/stages/arch/os).
* `ro` - makes the system a read-only OS. When run like this, you can simply unplug Raspberry Pi without shutting it down properly, without the risk of corrupting the file system. To temporary make the system writable (eg., to install updates), use the `rw` command. After applying all changes, run `ro` again to remount the system as read-only.
* `pikvm-repo` - adds the key and the [Pi-KVM](https://pikvm.org/repos) repo. It's needed for the watchdog, but it has other useful packages too. You can skip this stage.
* `watchdog` - sets up the hardware watchdog.
* `no-bluetooth` - disables the Bluetooth device and restores UART0/ttyAMA0 to GPIOs 14 and 15.
* `no-audit` - disables [Kernel audit](https://wiki.archlinux.org/index.php/Audit_framework).
* `ssh-root` - removes the `alarm` user, blocks the `root` password and and keys from [stages/ssh-root/pubkeys](https://github.com/pikvm/pi-builder/tree/master/stages/ssh-root/pubkeys) to the `~/.ssh/authorized_keys`. **This directory contains pi-builder dev's keys by default, make sure to change them!** This stage also disables UART login. In case you need it, you can create your own stage with similar functions.
* `ssh-keygen` - generates host SSH keys. The system will ALWAYS be rebuilt on this stage. You don't usually need manual key generation, but in case the system is loaded as read-only, SSH can't generate its own keys on startup.
* `__cleanup__` - cleans up temporary directories after build.

# Limitations
-----
Some files, like `/etc/host` and `/etc/hostname`, are automatically filled by docker and all changes made from the docker file will be lost. For the hostname, there is a hack in the `Makefile` that writes the hostname to the exported system, or sets this name on `make run`. So in case you need to change something in those files, add it to the `Makefile` in a similar way.

-----
# TL;DR
How to build a system for Raspberry Pi 4 and install it to the SD card:
```shell
$ git clone https://github.com/pikvm/pi-builder
$ cd pi-builder
$ make rpi4
$ make install
```

How to build a system with your own stage list:
```shell
$ make os BOARD=rpi4 STAGES="__init__ os __cleanup__"
```

You can see other commands and current build config like so:
```shell
$ make

===== Available commands  =====
    make                # Print this help
    rpi2|rpi3|rpi4|zero2w  # Build Arch-ARM rootfs with pre-defined config
    make shell          # Run Arch-ARM shell
    make binfmt         # Before build
    make scan           # Find all RPi devices in the local network
    make clean          # Remove the generated rootfs
    make install         # Format /dev/mmcblk0 and flash the filesystem

===== Running configuration =====
    PROJECT = common
    BOARD   = rpi4
    STAGES  = __init__ os watchdog no-bluetooth ro ssh-keygen __cleanup__

    BUILD_OPTS =
    HOSTNAME   = pi
    LOCALE     = en_US
    TIMEZONE   = Europe/Moscow

    CARD = /dev/mmcblk0

    QEMU_RM     = 1
```

* **Important**: Make sure the SD card directory is in the `CARD` variable in the Makefile and automount is turned off, or else the newly formatted SD card will be mounted to your system and the setup script will fail.
* **Very important**: Make sure your SSH key is in the [stages/arch/ssh-root/pubkeys](https://github.com/pikvm/pi-builder/tree/master/stages/arch/ssh-root/pubkeys) directory, or else you won't be able to log in to your system. Alternatively, don't use the `ssh-root` stage.
* **Most important**: Make sure to read the whole README to understand what you're doing.

-----
# License
Copyright (C) 2018-2023 by Maxim Devaev mdevaev@gmail.com

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see https://www.gnu.org/licenses/.

