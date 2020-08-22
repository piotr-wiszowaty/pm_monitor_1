# pm_monitor_1
A particulate matter monitor with BLE and UART interfaces.

The device is based on this [sensor](https://www.dfrobot.com/product-1272.html).
The measured particle concentrations are reported periodically over UART
(FDTI chip based interface) and over BLE. The included server listens for
the incoming BLE reports and stores them in an [InfluxDB](https://www.influxdata.com/) database.
The firmware is based on [Mecrisp Forth](http://mecrisp.sourceforge.net/).
