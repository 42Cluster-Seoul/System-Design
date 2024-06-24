
# bastion rsa key
aws ec2 create-key-pair \
--key-name 42cluster-bastion \
--key-type rsa \
--key-format pem \
--query "KeyMaterial" \
--output text > 42cluster-bastion.pem

chmod 400 42cluster-bastion.pem

# create cluster by cloudformation
aws cloudformation deploy --template-file  42cluster-configure.yaml --stack-name cluster42 \
--parameter-overrides KeyName=42cluster-bastion SgIngressSshCidr=$(curl -s ipinfo.io/ip)/32  \
MyIamUserAccessKeyID="${KEY}" \
MyIamUserSecretAccessKey= "${SECRET}" \
ClusterBaseName=cluster42 --region ap-northeast-2 \
WorkerNodeInstanceType=m5.large
