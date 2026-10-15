sed -E 's/(api_key=)[^ ]+/\1REDACTED/g' web-server/debug.log > debug-clean.log
