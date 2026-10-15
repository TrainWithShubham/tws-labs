#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
. "$LAB_LIB"
port=$(cat port.txt)
listening "$port" || { nohup nc -lk 127.0.0.1 "$port" > received.txt 2>/dev/null < /dev/null & sleep 0.5; }
