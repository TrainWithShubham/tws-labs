#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
[ -f cert.pem ] && [ -f key.pem ] || openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 1 -subj "/CN=app.test" -addext "subjectAltName=DNS:app.test" 2>/dev/null
