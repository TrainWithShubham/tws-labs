export PATH="$HOME/bin:$PATH"
aws ec2 describe-instances | grep '"running"' | grep -o 'i-[a-z0-9]*' > active_ec2.txt
aws lambda list-functions | grep -o '"FunctionName":"[a-z-]*"' | cut -d'"' -f4 > active_lambda.txt
