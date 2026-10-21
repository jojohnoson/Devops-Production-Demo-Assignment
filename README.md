## Overview

This project uses Terraform to build a highly available, three-tier network on AWS (region `ap-south-1`). It runs two nginx services (`nginx-a`, `nginx-b`) on ECS (EC2 launch type) behind one Application Load Balancer, and adds a serverless file-upload API (API Gateway, Lambda, S3). IAM roles follow least privilege, logs go to CloudWatch, and GitHub Actions validates every change.

## Architecture

```
Internet ──► ALB :80 ──┬─► Target group nginx-a ─► ECS tasks (EC2, bridge, dynamic ports)
                       └─► Target group nginx-b ─► ECS tasks

VPC 10.0.0.0/16 (2 AZs: ap-south-1a, ap-south-1b)
  public       (ALB, NAT gateway)    -> route: 0.0.0.0/0 via Internet Gateway
  private-app  (ECS EC2 instances)   -> route: 0.0.0.0/0 via NAT Gateway
  private-data (isolated, empty)     -> no internet route

Client ──► API Gateway (POST /upload) ─► Lambda ─► S3 (private, SSE, 30-day lifecycle)

Logs: ECS awslogs + Lambda ─► CloudWatch Logs
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI v2, configured with credentials for your own AWS account
- Region: `ap-south-1`
- Git (and `gh` CLI if you publish from the terminal)

Check your setup:

```bash
terraform -version
aws --version
aws sts get-caller-identity
```

## Repo layout

```
production-demo/
├── .github/workflows/terraform-ci.yml   # CI: fmt, validate, plan
├── environments/
│   └── demo/
│       ├── main.tf                      # provider + module wiring
│       ├── variable.tf
│       ├── output.tf
│       └── terraform.tfvars
├── modules/
│   ├── vpc/                             # VPC, subnets, IGW, NAT, route tables
│   ├── iam/                             # least-privilege roles
│   ├── ecs_alb/                         # ALB, target groups, ECS cluster, ASG, services
│   └── lambda_api/                      # S3, Lambda, API Gateway
│       └── src/handler.py
├── scripts/test.sh                      # end-to-end test script
├── docs/proof/                          # test output and screenshots
├── .gitignore
└── README.md
```

## Deploy

```bash
cd environments/demo
terraform fmt -recursive ../..
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Wait about 3-5 minutes after `apply` for the EC2 instances to register with ECS and for the ALB targets to turn healthy.

Check that the services are running:

```bash
aws ecs describe-services --cluster <project>-cluster --services nginx-a nginx-b \
  --query 'services[].{n:serviceName,run:runningCount,want:desiredCount}' --output table
```

> Replace `<project>-cluster` with the cluster name defined in your `ecs_alb` module.

**Cost note:** the NAT gateway, ALB and 2x `t3.small` instances cost roughly $0.12-0.15 per hour. Deploy, capture proof, then destroy.

## Test

Run the full test script:

```bash
./scripts/test.sh 2>&1 | tee docs/proof/test-output.txt
```

Or run the checks one by one:

```bash
cd environments/demo
ALB=$(terraform output -raw alb_dns_name)
API=$(terraform output -raw api_url)
BUCKET=$(terraform output -raw bucket_name)

# 1. Weighted a/b distribution at / (20 requests)
for i in $(seq 1 20); do curl -s "http://$ALB/"; done | sort | uniq -c

# 2. Path routing
curl -s "http://$ALB/a/"
curl -s "http://$ALB/b/"

# 3. Upload through API Gateway -> Lambda -> S3
echo "hello" > /tmp/test.txt
curl -s -X POST "$API/upload?filename=test.txt" -H "Content-Type: text/plain" --data-binary @/tmp/test.txt

# 4. Negative test (expect HTTP 400)
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$API/upload?filename=evil.exe" --data-binary "x"

# 5. Check the object landed in S3
aws s3 ls "s3://$BUCKET/uploads/"
```

## Destroy

```bash
cd environments/demo
terraform destroy
```

Then confirm nothing billable is left (all three should return empty):

```bash
aws ec2 describe-nat-gateways --query 'NatGateways[?State!=`deleted`].NatGatewayId'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-addresses --query 'Addresses[].AllocationId'
```

## IAM policies

All roles are defined in [`modules/iam/main.tf`](modules/iam/main.tf).

| Role | Trusted service | Permissions | Why |
|------|-----------------|-------------|-----|
| ECS task execution role | `ecs-tasks.amazonaws.com` | `logs:CreateLogStream`, `logs:PutLogEvents` on the ECS log group only | Containers can write their own logs and nothing else |
| ECS instance role | `ec2.amazonaws.com` | `AmazonEC2ContainerServiceforEC2Role`, `AmazonSSMManagedInstanceCore` (AWS managed) | Lets the ECS agent join the cluster, and allows SSM access instead of SSH |
| Lambda execution role | `lambda.amazonaws.com` | `s3:PutObject` on `bucket/uploads/*` only, plus CloudWatch log write on the function's log group | Lambda can upload files and log, nothing more |

## Demo proof

Evidence is stored in [`docs/proof/`](docs/proof/):

- `test-output.txt`: output of `scripts/test.sh` (a/b distribution, path routing, upload, S3 listing, Lambda and ECS logs)
- Screenshots: ALB target groups healthy, ECS services running, S3 object, Auto Scaling group
- Optional demo video: _add link here_

Key output (paste from `test-output.txt`):

```
<paste the uniq -c output and S3 listing here>
```

## Design decisions

- **Two AZs:** an ALB needs subnets in at least two AZs, and it gives high availability.
- **Single NAT gateway:** keeps cost down for a demo. Production should use one NAT per AZ.
- **Three subnet tiers:** public (ALB, NAT), private-app (ECS nodes), private-data (isolated, no internet route, ready for a future database).
- **Bridge networking with dynamic host ports:** allows several tasks on one EC2 host. The EC2 security group only accepts ports 32768-65535 from the ALB security group.
- **Weighted default listener action plus path rules:** `/` splits traffic 50/50 between `nginx-a` and `nginx-b`, while `/a/*` and `/b/*` route deterministically for testing.
- **ECS capacity provider with managed scaling:** the Auto Scaling group grows with demand. Task-level CPU autoscaling is also enabled.
- **Lambda input validation:** checks filename pattern, allowed extensions and maximum size (5 MB). Its role is limited to `PutObject` on `uploads/*`.
- **S3 hardening:** public access blocked, server-side encryption on, 30-day lifecycle expiry.
- **CI without secrets:** the validate job needs no credentials. The plan job runs only when the `AWS_ROLE_ARN` repository variable is set (OIDC, no static keys).

## CI/CD

`.github/workflows/terraform-ci.yml` runs on pull requests, pushes to `main`, and manual dispatch:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false` and `terraform validate`
3. `terraform plan`, only when the `AWS_ROLE_ARN` repository variable is configured

## Limitations / next steps

- Add HTTPS on the ALB (ACM certificate, 443 listener)
- Add a remote Terraform backend (S3 bucket and DynamoDB lock table)
- Add an ECR repository and a build-and-push pipeline for custom images
- Use one NAT gateway per AZ for production-grade availability
- Add an integration test job in CI after a manual apply