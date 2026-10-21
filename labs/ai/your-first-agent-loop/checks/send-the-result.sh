. "$LAB_LIB"
[ -f port.txt ] || fail "port.txt is missing: restart the lab."
port=$(tr -d '[:space:]' < port.txt)
[ -s final.json ] || fail "final.json is empty or missing: save the model's second reply there."
n=$(wc -l < notes.txt | tr -d ' ')
want=$(curl -s -m 2 -X POST "http://127.0.0.1:$port/chat" -d "{\"messages\":[{\"role\":\"user\",\"content\":\"how many lines are in notes.txt?\"},{\"role\":\"tool\",\"id\":\"call_1\",\"content\":\"$n\"}]}" | jq -S -c . 2>/dev/null)
[ -n "$want" ] || fail "The model is not answering on port $port. Restart the lab."
[ "$(jq -S -c . final.json 2>/dev/null)" = "$want" ] || fail "final.json is not the model's answer to your question plus the tool's result: the request must carry both messages, with the real line count."
ran_re '(curl|python3|wget)[[:space:]]' || fail "Send the second request for real (curl or a script)."
