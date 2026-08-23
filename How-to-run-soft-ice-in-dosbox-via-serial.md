# How to run Soft-ICE in DOSBox via serial connection

NOTE: It is a **failed** attempt, that is, the slave terminal does not 
seem to work!

NOTE: It looks like none of the stock DOSBox nor DOSBox-X builds have the
Serial or TCP/IP code compiled in so you have to build the DOSBox-staging
from source (e.g. Macports below or brew)!

## Prerequisites
* OSX: Mojave @version
* Macports: @version
* Ports needed:
  - dosbox-staging @version
  - socat
  - inet-utils for gtelnet
  - screen

# The virtual TTY setup

```bash
sudo socat -d -d PTY,link=/dev/vserial1,rawer,echo=0,crtscts=1,perm=666 \
    PTY,link=$HOME/dev_softice,rawer,echo=0,crtscts=1,perm=666
```

# The drive_z setup
* Soft-ICE:
  - s-ice.exe
  - ldr.exe
  - s-ice.dat
  - emmsetup.exe
Run `emmsetup.exe` to allow for the EMM config.
* FreeDOS:
  - mode.com for port setup

# Starting the terminal program

## screen(1)

```sh
sudo chown $(whoami) ~/dev_softice
sudo chmod a+rwx /dev/vserial1
screen ~/dev_softice 9600
```
To exit, type <kbd>esc</kbd> <kbd>CTRL-a</kbd> <kbd>SHIFT-K</kbd> then <kbd>y</kbd>.

## cu(1)
```
sudo cu -l /Users/mac/dev_softice -s 9600
```
To exit, type <kbd>~</kbd> then <kbd>.</kbd>.

# DosBOX config
In `$HOME/Library/Preferences/DOSBox/dosbox-staging.conf`.

For Soft-ICE to be even able to start:
```ini
[dos]
xms = false
ems = false
umb = false
```

For the serial connection:
```ini
[serial]
serial1 = direct realport:vserial1 baudrate:9600 bytesize:8 stopbit:1 parity:N rxdelay:100
```

Alternatively, inside DOSBox, from the prompt:
```bash
c:\> serial 1 direct realport:vserial1 baudrate:9600 bytesize:8 \
            stopbit:1 parity:N rxdelay:100
```

# Soft-ice start and setup
```sh
z:\si\s-ice.exe
# Press <kbd>y</kbd>.
z:\si\mode.com com1 baud=9600 stop=1 data=8 parity=N
# Verify with
z:\si\mode.com BAUDHARD=1
# Test serial terminal
echo Hi > com1
```

Inside Soft-ICE:
```sh
# Press <kbd>CTRL-D</kbd> to pop up the debugger
SERIAL ON COM1 9600
ALTSCR ON
```

# Alternative transport (TCP/IP).

Use the following DOSBox config:
```ini
serial1 nullmodem port:1833
```

and a NetCat
```
nc localhost:1833
```
or telnet as a terminal
```
gtelnet localhost 1833
```

No virtual PTY redirector needed.