aws cloudformation create-stack \
  --region eu-central-1 \
  --stack-name phobosys-2-eks-stack \
  --capabilities CAPABILITY_NAMED_IAM \
  --template-body file://"eks-vpc-roles.yaml"
