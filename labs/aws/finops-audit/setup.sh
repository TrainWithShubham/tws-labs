mkdir -p "$HOME/bin" "$HOME/.fixtures"

cat > "$HOME/.fixtures/instances.json" <<'EOF'
{"Instances":[
{"InstanceId":"i-0a1b2c3d4e5f60001","State":"running"},
{"InstanceId":"i-0a1b2c3d4e5f60002","State":"stopped"},
{"InstanceId":"i-0a1b2c3d4e5f60003","State":"running"}
]}
EOF

cat > "$HOME/.fixtures/functions.json" <<'EOF'
{"Functions":[
{"FunctionName":"orders-api","Runtime":"python3.12"},
{"FunctionName":"image-resizer","Runtime":"nodejs20.x"},
{"FunctionName":"nightly-report","Runtime":"python3.12"}
]}
EOF

cat > "$HOME/.fixtures/volumes.json" <<'EOF'
{"Volumes":[
{"VolumeId":"vol-0a1b2c3d4e5f60001","State":"available"},
{"VolumeId":"vol-0a1b2c3d4e5f60002","State":"in-use"},
{"VolumeId":"vol-0a1b2c3d4e5f60003","State":"available"}
]}
EOF

cat > "$HOME/.fixtures/buckets.json" <<'EOF'
{"Buckets":[
{"Name":"finops-demo-logs"},
{"Name":"finops-demo-backups"},
{"Name":"finops-demo-assets"}
]}
EOF

cat > "$HOME/.fixtures/rds.json" <<'EOF'
{"DBInstances":[
{"DBInstanceIdentifier":"orders-db","Engine":"postgres"},
{"DBInstanceIdentifier":"analytics-db","Engine":"mysql"}
]}
EOF

cat > "$HOME/.fixtures/tables.json" <<'EOF'
{"TableNames":[
"orders",
"sessions",
"audit_log"
]}
EOF

cat > "$HOME/.fixtures/addresses.json" <<'EOF'
{"Addresses":[
{"AllocationId":"eipalloc-0a1b2c3d40001","AssociationId":null},
{"AllocationId":"eipalloc-0a1b2c3d40002","AssociationId":null},
{"AllocationId":"eipalloc-0a1b2c3d40003","AssociationId":"eipassoc-0a1b2c3d40003"}
]}
EOF

cat > "$HOME/.fixtures/nat.json" <<'EOF'
{"NatGateways":[
{"NatGatewayId":"nat-0a1b2c3d4e5f60001","State":"available"},
{"NatGatewayId":"nat-0a1b2c3d4e5f60002","State":"deleted"}
]}
EOF

cat > "$HOME/bin/aws" <<'EOF'
#!/bin/bash
f="$HOME/.fixtures"
case "$1 $2" in
  "ec2 describe-instances")     cat "$f/instances.json" ;;
  "lambda list-functions")      cat "$f/functions.json" ;;
  "ec2 describe-volumes")       cat "$f/volumes.json" ;;
  "s3api list-buckets")         cat "$f/buckets.json" ;;
  "rds describe-db-instances")  cat "$f/rds.json" ;;
  "dynamodb list-tables")       cat "$f/tables.json" ;;
  "ec2 describe-addresses")     cat "$f/addresses.json" ;;
  "ec2 describe-nat-gateways")  cat "$f/nat.json" ;;
  *) echo "aws: this lab only supports the audit commands from the task hints" >&2; exit 1 ;;
esac
EOF
chmod +x "$HOME/bin/aws"
