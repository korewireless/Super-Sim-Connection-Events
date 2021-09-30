#!/bin/bash
export TF_VAR_your_aws_region='<YOUR_AWS_REGION>'
export TF_VAR_external_id=$(openssl rand -hex 40)
export TF_VAR_your_computer_external_ip=$(curl -s https://checkip.amazonaws.com/)
terraform init
terraform validate
terraform apply
