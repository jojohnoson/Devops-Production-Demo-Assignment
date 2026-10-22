# Production Demo: AWS Infrastructure with Terraform

A small, production-style AWS environment (region `ap-south-1`) built entirely with Terraform. Two nginx services run on **ECS (EC2 launch type)** behind **one Application Load Balancer**, and a **serverless file-upload API** (API Gateway, Lambda, S3) sits alongside it. IAM follows least privilege, logs go to CloudWatch, and GitHub Actions validates every change.

## Table of contents

1. [Assignment coverage](#assignment-coverage)
2. [Architecture](#architecture)
3. [Repository layout](#repository-layout)
4. [Prerequisites](#prerequisites)
5. [Deploy](#deploy)
6. [Test](#test)
7. [Demo proof](#demo-proof)
8. [Destroy](#destroy)
9. [IAM policies](#iam-policies)
10. [CI/CD](#cicd)
11. [Design decisions](#design-decisions)
12. [Limitations and next steps](#limitations-and-next-steps)

## Assignment coverage

### Core features

| # | Requirement | Implementation | Where |
|---|---|---|---|
| 1 | **Networking:** VPC with public, private-app and private-data subnets, route tables, IGW, NAT | VPC `10.0.0.0/16`, 2 AZs, 3 subnet tiers, Internet Gateway, one NAT Gateway, separate route tables (the data tier has no internet route) | `modules/vpc` |
| 2 | **ECS on EC2:** cluster on EC2 via Auto Scaling Group, two services `nginx-a` and `nginx-b` serving different pages | ECS cluster, launch template + ASG, capacity provider with managed scaling, one task definition and one service per nginx page (official `nginx` image, HTML written at container start) | `modules/ecs` |
| 3 | **Routing and load balancer:** one ALB, listener on port 80, target groups, round-robin | One ALB, HTTP :80 listener, target groups `a` and `b`, 50/50 weighted default action, path rules `/a/*` and `/b/*` | `modules/alb` |
| 4 | **Serverless API:** API Gateway + Lambda + S3, `POST /upload` | HTTP API route `POST /upload`, Python Lambda that validates and stores the file, private S3 bucket with encryption and a 30-day lifecycle rule | `modules/lambda_api` |
| 5 | **IAM:** least-privilege roles and policies | ECS task execution role, EC2 instance role and instance profile, Lambda execution role, all with scoped permissions | `modules/iam` |
| 6 | **Observability:** ECS and Lambda logs in CloudWatch | ECS `awslogs` driver to a dedicated log group, Lambda log group, Container Insights enabled | `modules/ecs`, `modules/lambda_api` |

### Bonus items

| Bonus | Status |
|---|---|
| Health checks and autoscaling for ECS tasks | Implemented: ALB health checks, CPU target-tracking autoscaling (2-4 tasks) per service |
| GitHub Actions pipeline (`fmt`, `validate`, optional `plan`) | Implemented, see [CI/CD](#cicd) |
| ECR and image build pipeline | Not included, see [next steps](#limitations-and-next-steps) |
| HTTPS on the ALB with ACM | Not included |
| CI that applies Terraform | Not included |
| Integration tests in CI | Not included |

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

### How traffic is routed

| Request | Handled by | Result |
|---|---|---|
| `/a/` | Listener rule (priority 10) | Always `nginx-a` |
| `/b/` | Listener rule (priority 20) | Always `nginx-b` |
| `/` | Default action | 50/50 split between `nginx-a` and `nginx-b` |
| `POST /upload` | API Gateway | Lambda validates the file and writes it to S3 |

Inside each target group the ALB round-robins across healthy tasks.

## Repository layout

```
production-demo/
├── .github/workflows/terraform-ci.yml   # CI: fmt, validate, plan
├── docs/proof/                          # test output and screenshots
├── environments/
│   └── demo/
│       ├── main.tf                      # provider + module wiring
│       ├── variable.tf
│       ├── output.tf
│       ├── versions.tf
│       ├── terraform.tfvars
│       └── .terraform.lock.hcl
├── modules/
│   ├── vpc/                             # VPC, subnets, IGW, NAT, route tables
│   ├── iam/                             # least-privilege roles and policies
│   ├── alb/                             # ALB, target groups, listener, rules
│   ├── ecs/                             # cluster, ASG, task definitions, services
│   └── lambda_api/                      # S3, Lambda, API Gateway
│       └── src/handler.py
├── scripts/
│   ├── test.sh                          # end-to-end test script
│   ├── create_s3.sh                     # S3 bucket helper
│   └── destroy_s3.sh                    # S3 bucket helper
├── .gitignore
└── README.md
```

Each module has `main.tf`, `variable.tf` and `output.tf`.

## Prerequisites

| Requirement | Detail |
|---|---|
| AWS account | Your own account, with permissions to create VPC, ECS, EC2, ELB, IAM, Lambda, API Gateway, S3 and CloudWatch resources |
| Terraform | >= 1.5 |
| AWS CLI | v2, configured with credentials (`aws configure`) |
| Region | `ap-south-1` |
| Other | Git and `curl` |

Check your setup:

```bash
terraform -version
aws --version
aws sts get-caller-identity
```

## Deploy

```bash
cd environments/demo
terraform init
terraform fmt -recursive ../..
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Wait about 3-5 minutes after `apply` for the EC2 instances to register with ECS and for the ALB targets to turn healthy.

Check that both services are running:

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)

aws ecs describe-services --cluster "$CLUSTER" --services nginx-a nginx-b \
  --query 'services[].{n:serviceName,run:runningCount,want:desiredCount}' --output table
```

> **Cost note:** the NAT gateway, ALB and 2x `t3.small` instances cost roughly $0.12-0.15 per hour. Deploy, capture proof, then destroy.

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

| Test | Expected result |
|---|---|
| Distribution at `/` | Both `nginx-a` and `nginx-b` lines appear in the `uniq -c` output |
| `/a/` and `/b/` | Each path always returns its own service's page |
| Upload `test.txt` | HTTP 200 and a JSON body with the S3 key |
| Upload `evil.exe` | HTTP 400 (rejected by Lambda validation) |
| S3 listing | The uploaded object appears under `uploads/` |

## Demo proof

### nginx-a and nginx-b served by the ALB

<p align="center">
  <img width="800" alt="nginx-a response" src="https://github.com/user-attachments/assets/8a6306a2-347e-4f02-b47c-4198c83c40b5" />
</p>
<p align="center"><em>nginx-a response</em></p>

<p align="center">
  <img width="800" alt="nginx-b response" src="https://github.com/user-attachments/assets/ad007cf6-c4fe-495c-8f86-f3ae4dc486c6" />
</p>
<p align="center"><em>nginx-b response</em></p>

### Terminal verification

<p align="center">
  <img width="700" alt="Terminal verification" src="https://github.com/user-attachments/assets/af9aabbc-0699-45e4-bb9e-1d0d4638f952" />
</p>

### Application Load Balancer

<p align="center">
  <img width="800" alt="ALB and target groups" src="https://github.com/user-attachments/assets/fbeb1b5c-67d3-41e7-b836-51737bab85ed" />
</p>

### ECS services

<p align="center">
  <img width="800" alt="ECS services running" src="https://github.com/user-attachments/assets/5a7e0518-29f7-4f86-8bbd-8432ba477c9b" />
</p>

<!-- Add after deploying lambda_api: upload curl output, S3 object listing, Lambda CloudWatch logs -->

Full command output is stored in [`docs/proof/`](docs/proof/).

## Destroy

```bash
cd environments/demo
terraform destroy
```

Then confirm nothing billable is left (all three commands should return empty):

```bash
aws ec2 describe-nat-gateways --query 'NatGateways[?State!=`deleted`].NatGatewayId'
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-addresses --query 'Addresses[].AllocationId'
```

## IAM policies

All roles and policies are defined in Terraform in [`modules/iam/main.tf`](modules/iam/main.tf).

| Role | Trusted service | Permissions | Why |
|---|---|---|---|
| ECS task execution role | `ecs-tasks.amazonaws.com` | `logs:CreateLogStream`, `logs:PutLogEvents` on the ECS log group only | Containers can write their own logs and nothing else |
| ECS instance role | `ec2.amazonaws.com` | `AmazonEC2ContainerServiceforEC2Role`, `AmazonSSMManagedInstanceCore` (AWS managed) | Lets the ECS agent join the cluster and allows SSM access instead of SSH |
| Lambda execution role | `lambda.amazonaws.com` | `s3:PutObject` on `bucket/uploads/*` only, plus CloudWatch log write on the function's log group | Lambda can upload files and log, nothing more |

Notes:

- API Gateway needs no role. It invokes Lambda through a resource-based permission (`aws_lambda_permission`).
- The S3 bucket needs no role. Access is controlled by the Lambda role's scoped policy, and public access is blocked.
- The ECS task role is not created because the nginx containers do not call AWS APIs.

## CI/CD

`.github/workflows/terraform-ci.yml` runs on pull requests, pushes to `main`, and manual dispatch:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false` and `terraform validate`
3. `terraform plan`, only when the `AWS_ROLE_ARN` repository variable is configured (OIDC, no static keys)

The validate job needs no credentials.

## Design decisions

| Decision | Reason |
|---|---|
| Two AZs | An ALB needs subnets in at least two AZs, and it gives high availability |
| Single NAT gateway | Keeps demo cost low. Production should use one NAT per AZ |
| Three subnet tiers | Public (ALB, NAT), private-app (ECS nodes), private-data (isolated, ready for a future database) |
| Bridge networking with dynamic host ports | Allows several tasks on one EC2 host. The EC2 security group accepts ports 32768-65535 from the ALB security group only |
| One target group per ECS service | ECS allows a target group to be attached to only one service |
| Weighted default action plus path rules | `/` splits 50/50 between `nginx-a` and `nginx-b`, while `/a/*` and `/b/*` route deterministically for testing |
| ECS capacity provider with managed scaling | The Auto Scaling group grows with demand. Task-level CPU autoscaling is also enabled |
| Lambda input validation | Checks filename pattern, allowed extensions and maximum size (5 MB) |
| S3 hardening | Public access blocked, server-side encryption on, 30-day lifecycle expiry |

## Limitations and next steps

- Add HTTPS on the ALB (ACM certificate, 443 listener)
- Add a remote Terraform backend (S3 bucket and DynamoDB lock table)
- Add an ECR repository and a build-and-push pipeline for custom images
- Use one NAT gateway per AZ for production-grade availability
- Apply Terraform from GitHub Actions and add an integration test job (curl check after apply)