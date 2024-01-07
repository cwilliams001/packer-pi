#!/bin/bash
sleep 10
APN_NAME=$(cat /opt/source/apn_name.txt)
sleep 5
echo -e "AT+CGDCONT=1,\"IPV4V6\",\"${APN_NAME}\"\r" > /dev/ttyUSB2
sleep 2
echo -e "AT+QCFG=\"usbnet\",1\r" > /dev/ttyUSB2
sleep 2
echo -e "AT+CFUN=1,1\r" > /dev/ttyUSB2
