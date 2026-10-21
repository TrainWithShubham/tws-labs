. "$LAB_LIB"
[ -f port.txt ] || fail "port.txt is missing: restart the lab."
port=$(tr -d '[:space:]' < port.txt)
[ -s reply.json ] || fail "reply.json is empty or missing: save the answer there."
want=$(curl -s -m 2 -X POST "http://127.0.0.1:$port/chat" -d '{"messages":[{"role":"user","content":"how many lines are in notes.txt?"}]}' | jq -S -c . 2>/dev/null)
[ -n "$want" ] || fail "The model is not answering on port $port. Restart the lab."
[ "$(jq -S -c . reply.json 2>/dev/null)" = "$want" ] || fail "reply.json is not the model's answer to that message: send exactly the body from the task."
ran_re '(curl|python3|wget)[[:space:]]' || fail "Send the message with a real request (curl or a script), not by typing the answer."
