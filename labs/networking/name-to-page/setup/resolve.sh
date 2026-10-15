#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
. "$LAB_LIB"
port=$(cat port.txt)
listening "$port" || { nohup bash server.sh > /dev/null 2>&1 < /dev/null & sleep 0.6; }
