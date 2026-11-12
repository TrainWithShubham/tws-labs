printf '%s\n' '{"Resources":{"Jobs":{"Type":"AWS::SQS::Queue","Properties":{"QueueName":"jobs"}}},"Outputs":{"QueueArn":{"Value":{"Fn::GetAtt":["Jobs","Arn"]}}}}' > stack.json
