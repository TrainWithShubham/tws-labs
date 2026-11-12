. "$LAB_LIB"
emulator_ready
b=tws-labs-notes
aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || fail "There is no bucket named $b yet. Make it first."
cfg=$(aws s3api get-bucket-lifecycle-configuration --bucket "$b" --output json 2>/dev/null) || fail "The bucket has no lifecycle configuration yet."
printf '%s' "$cfg" | python3 -c '
import json, sys
rules = json.load(sys.stdin).get("Rules", [])
def prefix(r):
    f = r.get("Filter") or {}
    return f.get("Prefix", (f.get("And") or {}).get("Prefix", r.get("Prefix")))
good = [r for r in rules if prefix(r) == "tmp/"]
if not good: print("No rule applies to the prefix tmp/ yet."); sys.exit(1)
if not any(r.get("Status") == "Enabled" for r in good): print("The rule for tmp/ exists, but it is not Enabled."); sys.exit(1)
if not any(r.get("Status") == "Enabled" and (r.get("Expiration") or {}).get("Days") == 7 for r in good): print("The rule for tmp/ should expire objects after 7 days."); sys.exit(1)
' || exit 1
