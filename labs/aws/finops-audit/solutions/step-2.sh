aws ec2 describe-volumes | grep '"available"' | grep -o 'vol-[a-z0-9]*' > unattached_ebs.txt
aws s3api list-buckets | grep -o '"Name":"[a-z0-9-]*"' | cut -d'"' -f4 > s3_buckets.txt
