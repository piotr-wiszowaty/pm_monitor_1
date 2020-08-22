#!/usr/bin/env python3

import argparse
import datetime
import queue
import struct
import syslog
import threading
import urllib.request
import bluetooth._bluetooth as bluez

OGF_LE_CTL = 0x08
OCF_LE_SET_SCAN_ENABLE = 0x000C

LE_ADVERTISING_REPORT_EVENT = 0x3e
LE_ADVERTISING_REPORT_SUBEVENT = 0x02
ADV_NONCONN_IND = 0x03

sensors = {}

parser = argparse.ArgumentParser()
parser.add_argument("-f", "--config-file", metavar="CONFIG-FILE", required=True)
parser.add_argument("-d", "--db-url", metavar="URL", default="http://localhost:8086/write?db=home")
args = parser.parse_args()
with open(args.config_file, "rt") as f:
    for line in f:
        addr, loc = line.strip().split(" ")
        sensors[addr] = loc

def hci_toggle_le_scan(sock, enable):
    cmd_pkt = struct.pack("<BB", enable, 0x00)
    bluez.hci_send_cmd(sock, OGF_LE_CTL, OCF_LE_SET_SCAN_ENABLE, cmd_pkt)

def hci_enable_le_scan(sock):
    hci_toggle_le_scan(sock, 0x01)

def hci_disable_le_scan(sock):
    hci_toggle_le_scan(sock, 0x00)

def parse_beacon(packet):
    address_type = packet[0]
    address_bytes = list(packet[1:7])
    address_bytes.reverse()
    address = ":".join(map(lambda b: "%02X" % b, address_bytes))
    if not address in sensors:
        #syslog.syslog("skip {}".format(address))
        return []
    data_length = packet[7]
    #syslog.syslog("address_type=0x{:02x} address={} data_length={}".format(address_type, address, data_length))
    if data_length < 19:
        return []
    offset = 0
    while offset < data_length:
        ad_length = packet[8+offset]
        ad_type = packet[8+offset+1]
        ad_data = packet[8+offset+2:8+offset+2+ad_length-1]
        offset += ad_length + 1
        #syslog.syslog("ad_length={} ad_type={} ad_data={} offset={} packet={}".format(ad_length, ad_type, ad_data, offset, packet))
        if ad_type == 0x09:
            complete_name = ad_data.decode()
        elif ad_type == 0xff:
            pm1_0, pm2_5, pm10 = struct.unpack(">HHH", ad_data)
            #syslog.syslog("ad_data={} pm1.0={} pm2.5={} pm10={}".format(ad_data, pm1_0, pm2_5, pm10))
        else:
            syslog.syslog("invalid packet detected: {}".format(packet))
            return []
    (rssi,) = struct.unpack("b", packet[-1:])
    return (address, complete_name, pm1_0, pm2_5, pm10, rssi)

def parse_packets(sock, count):
    results = []
    for i in range(count):
        packet = sock.recv(255)
        #syslog.syslog(f"{datetime.datetime.now()} | {str(packet)}")
        pkt_type = packet[0]
        event_code = packet[1]
        pkt_len = packet[2]
        subevent_code = packet[3]
        if event_code == LE_ADVERTISING_REPORT_EVENT and subevent_code == LE_ADVERTISING_REPORT_SUBEVENT:
            num_reports, event_type = struct.unpack("BB", packet[4:6])
            if num_reports == 1 and event_type == ADV_NONCONN_IND:
                results.append(parse_beacon(packet[6:]))
    return [r for r in results if r]

class DBWriterThread(threading.Thread):
    def __init__(self, q, db_url):
        threading.Thread.__init__(self)
        self.q = q
        self.db_url = db_url

    def run(self):
        batch = []
        while True:
            try:
                batch.append(self.q.get(timeout=15))
            except queue.Empty:
                if batch:
                    complete_name, _, _, _, _, location = batch[0]
                    pm1_0 = int(sum(map(lambda r: r[1], batch)) / len(batch))
                    pm2_5 = int(sum(map(lambda r: r[2], batch)) / len(batch))
                    pm10  = int(sum(map(lambda r: r[3], batch)) / len(batch))
                    rssi  = int(sum(map(lambda r: r[4], batch)) / len(batch))
                    payload = "dust,location={},name={} pm1_0={},pm2_5={},pm10={},rssi={}".format(location, complete_name, pm1_0, pm2_5, pm10, rssi)
                    urllib.request.urlopen(self.db_url, data=bytes(payload, "utf-8"))
                    batch = []

q = queue.Queue()
t = DBWriterThread(q, db_url=args.db_url)
t.start()
try:
    sock = bluez.hci_open_dev(0)
    hci_enable_le_scan(sock)

    old_filter = sock.getsockopt(bluez.SOL_HCI, bluez.HCI_FILTER, 14)
    flt = bluez.hci_filter_new()
    bluez.hci_filter_all_events(flt)
    bluez.hci_filter_set_ptype(flt, bluez.HCI_EVENT_PKT)
    sock.setsockopt(bluez.SOL_HCI, bluez.HCI_FILTER, flt)

    while True:
        results = parse_packets(sock, 10)
        for address, complete_name, pm1_0, pm2_5, pm10, rssi in results:
            #syslog.syslog("address={}, complete_name={}, pm1_0={}, pm2_5={}, pm10={}, rssi={}".format(address, complete_name, pm1_0, pm2_5, pm10, rssi))
            q.put((complete_name, pm1_0, pm2_5, pm10, rssi, sensors[address]))
except KeyboardInterrupt:
    pass
