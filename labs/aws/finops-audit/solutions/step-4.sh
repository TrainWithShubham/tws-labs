aws ec2 describe-addresses | grep '"AssociationId":null' | grep -o 'eipalloc-[a-z0-9]*' > idle_eips.txt
aws ec2 describe-nat-gateways | grep '"State":"available"' | grep -o 'nat-[a-z0-9]*' > nat_gateways.txt
