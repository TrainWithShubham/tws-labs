#!/bin/bash
mkdir -p reports logs
[ -f logs/service.log ] || cp .fixtures/service.log logs/service.log
