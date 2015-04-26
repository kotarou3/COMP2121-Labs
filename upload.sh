#!/bin/sh

set -ex
avrdude -c stk500v2 -p m2560 -P /dev/ttyACM0 -F -D -b 115200 -U flash:w:"$1":e
