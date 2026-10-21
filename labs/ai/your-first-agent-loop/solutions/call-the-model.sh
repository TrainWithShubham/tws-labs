curl -s -X POST "http://127.0.0.1:$(cat port.txt)/chat" -d '{"messages":[{"role":"user","content":"how many lines are in notes.txt?"}]}' > reply.json
