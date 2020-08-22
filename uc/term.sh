#!/bin/sh
picocom -b 1000000 /dev/ttyUSB0 --imap lfcrlf,crcrlf --omap delbs,crlf --flow h --send-cmd "xfr -c -e -s -I $HOME/include/ARM/STM32G0x1"
