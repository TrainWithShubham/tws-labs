. "$LAB_LIB"
emulator_ready
[ -f stack.json ] || fail "There is no stack.json in your home folder."
python3 - stack.json <<'PY' || exit 1
import json, sys
try: t = json.load(open(sys.argv[1]))
except Exception as e: print("stack.json is not valid JSON: %s" % e); sys.exit(1)
res = t.get("Resources", {})
if not any(r.get("Type") == "AWS::S3::Bucket" for r in res.values()): print("Keep the bucket: stack.json should still declare an AWS::S3::Bucket."); sys.exit(1)
queues = {n: r for n, r in res.items() if r.get("Type") == "AWS::SQS::Queue"}
if not queues: print("stack.json does not declare an AWS::SQS::Queue yet."); sys.exit(1)
name = next((n for n, r in queues.items() if (r.get("Properties") or {}).get("QueueName") == "jobs"), None)
if not name: print("The queue should be named jobs (Properties, QueueName)."); sys.exit(1)
v = (t.get("Outputs", {}).get("QueueArn") or {}).get("Value")
ok = isinstance(v, dict) and (v.get("Fn::GetAtt") in ([name, "Arn"], "%s.Arn" % name))
if not ok: print("Add an output QueueArn whose Value is {\"Fn::GetAtt\": [\"%s\", \"Arn\"]}." % name); sys.exit(1)
PY
aws cloudformation validate-template --template-body file://stack.json >/dev/null 2>&1 || fail "CloudFormation does not accept this template yet. Try: aws cloudformation validate-template --template-body file://stack.json"
