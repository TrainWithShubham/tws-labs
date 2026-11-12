. "$LAB_LIB"
emulator_ready
b=tws-labs-notes
pol=$(aws s3api get-bucket-policy --bucket "$b" --query Policy --output text 2>/dev/null) || fail "No policy could be read from $b yet. Does the bucket exist, and did the put-bucket-policy command succeed?"
printf '%s' "$pol" | python3 -c '
import json, sys
b = sys.argv[1]
try: doc = json.load(sys.stdin)
except Exception: print("The policy is not valid JSON."); sys.exit(1)
def listed(v): return v if isinstance(v, list) else [v]
for st in listed(doc.get("Statement", [])):
    if st.get("Effect") != "Deny": continue
    if st.get("Principal") not in ("*", {"AWS": "*"}): continue
    if "s3:*" not in listed(st.get("Action", [])): continue
    res = listed(st.get("Resource", []))
    if f"arn:aws:s3:::{b}" not in res or f"arn:aws:s3:::{b}/*" not in res:
        print("The statement must cover both the bucket and the objects in it."); sys.exit(1)
    cond = (st.get("Condition") or {}).get("Bool", {}).get("aws:SecureTransport")
    if str(cond).lower() != "false":
        print("The condition should be aws:SecureTransport equal to false."); sys.exit(1)
    sys.exit(0)
print("No Deny statement for s3:* to everyone yet."); sys.exit(1)
' "$b" || exit 1
