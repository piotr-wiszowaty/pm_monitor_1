pm_monitor_1
============

A particulate matter monitor with BLE and UART interfaces.

The device is based on this [sensor](https://www.dfrobot.com/product-1272.html).
The measured particle concentrations are reported periodically over UART
(FDTI chip based interface) and over BLE. The included server listens for
the incoming BLE reports and stores them in an [InfluxDB](https://www.influxdata.com/) database.

Firmware
--------

The firmware is based on [Mecrisp-Stellaris Forth](http://mecrisp.sourceforge.net/).
Flashing firmware can be done using a communication program (minicom, picocom, etc):

0. flash the Mecrisp-Stellaris Forth core (see note below),
1. send `flash.forth`,
2. send `turnkey.forth`,
3. reset the device.

The microcontroller register and bit field constants can be downloaded from [here](https://github.com/piotr-wiszowaty/comfoh).

Note that to utilize hardware flow control (as in `uc/term.sh`) you need to enable USART2 RTS/CTS
lines in the Mecrisp-Stellaris Forth core.
