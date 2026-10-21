curl -s -X POST "http://127.0.0.1:$(cat port.txt)/chat" -d '{}' > reply.json
