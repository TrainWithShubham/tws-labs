aws rds describe-db-instances | grep -o '"DBInstanceIdentifier":"[a-z0-9-]*"' | cut -d'"' -f4 > rds_instances.txt
aws dynamodb list-tables | grep -o '^"[a-z0-9_-]*"' | tr -d '"' > dynamodb_tables.txt
