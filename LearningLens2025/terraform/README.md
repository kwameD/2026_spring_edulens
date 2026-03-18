# EduLense Terraform Infrastructure Documentation

This directory contains the Infrastructure as Code (IaC) for deploying the **LearningLens2025** application to AWS.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS Infrastructure                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         AWS Amplify (Flutter Web Frontend)           │   │
│  │  • Auto-deploys from GitHub                          │   │
│  │  • Global CDN via CloudFront                         │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         API Gateway (REST API)                       │   │
│  │  • /ai-log → Lambda: ai_log                          │   │
│  │  • /game-data → Lambda: game_data                    │   │
│  │  • /code-eval → Lambda: code_eval                    │   │
│  │  • /reflections → Lambda: reflections                │   │
│  └──────────────────────────────────────────────────────┘   │
│                          ↓                                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           AWS Lambda Functions (Serverless)           │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │ AI Log (Node.js) │ Game Data │ Code Eval │ Reflections │  │
│  └───────────────────────────────────────────────────────┘  │
│                ↓              ↓              ↓               │
│  ┌──────────────────┐ ┌──────────────────┐ ┌────────────┐  │
│  │  DSQL Database   │ │ DynamoDB Tables  │ │  S3 Bucket │  │
│  │  (Primary Data)  │ │  (Cache/Logs)    │ │(User Code) │  │
│  └──────────────────┘ └──────────────────┘ └────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         EC2 + Moodle LMS Instance                    │   │
│  │  • Bitnami Moodle 5.0 AMI                            │   │
│  │  • Elastic IP for persistent URL                     │   │
│  │  • MariaDB database included                         │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │    Code Evaluation Pipeline                          │   │
│  │  • ECS Fargate Cluster                               │   │
│  │  • ECR Repository (Program Grader Docker images)     │   │
│  │  • CloudWatch Logs                                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed (`terraform --version`)
3. **AWS CLI** configured (`aws configure`)
4. **GitHub Personal Access Token** (for Amplify)
5. **Docker** (optional, for building ECR images)

## Setup Instructions

### 1. Create Terraform Variables File

Copy the example variables file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values:
- `github_token`: Create at https://github.com/settings/tokens
- `moodle_username` & `moodle_password`: Credentials for Moodle service account
- Other optional values for customization

### 2. Initialize Terraform

```bash
terraform init
```

This downloads required providers and sets up the Terraform backend.

### 3. Validate Configuration

```bash
terraform validate
```

Checks for syntax errors and misconfigurations.

### 4. Plan Deployment

```bash
terraform plan -out=tfplan
```

This shows what resources will be created without making changes.

### 5. Apply Infrastructure

```bash
terraform apply tfplan
```

This creates all AWS resources. Takes approximately 10-15 minutes.

### 6. Retrieve Deployment Information

```bash
terraform output deployment_instructions
```

## File Structure

```
terraform/
├── main.tf                      # Main resources (Moodle, Lambda, ECR, DSQL)
├── code_eval.tf                # Code evaluation (ECS, Lambda functions)
├── api_gateway.tf              # REST API Gateway and endpoint integrations
├── dynamodb.tf                 # Optional DynamoDB tables
├── variables.tf                # Input variable definitions
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Example variables (copy to terraform.tfvars)
└── README.md                   # This file
```

## Resource Details

### Frontend (AWS Amplify)
- Automatically deploys Flutter web app from GitHub branch
- Uses CloudFront for CDN
- Supports pull request preview environments

### Backend APIs (Lambda + API Gateway)
- **ai_log**: Logs AI/LLM interactions
- **game_data**: Manages game scores and leaderboards
- **code_eval**: Evaluates student code submissions
- **reflections**: Stores student reflection data

### Database (DSQL)
- Aurora DSQL for primary data storage
- Relational database compatible with PostgreSQL
- Automatic backups and point-in-time recovery

### Optional DynamoDB
- High-speed access for AI logs
- Game data caching
- Reflection metadata
- Can be disabled by setting `enable_dynamodb = false`

### Code Evaluation (ECS + ECR)
- AWS Fargate for serverless container execution
- Stores grading Docker images in ECR
- CloudWatch logs for monitoring

### Moodle LMS (EC2)
- Bitnami Moodle 5.0 pre-configured AMI
- Elastic IP for persistent URL
- MariaDB database
- SSH access via generated key pair

### Storage (S3)
- User code submissions
- Custom application data
- File uploads from students

## Common Commands

### View Stack Output
```bash
terraform output
```

### Get Specific Output
```bash
terraform output amplify_app_url
terraform output api_gateway_url
terraform output moodle_elastic_ip
```

### Update Specific Resource
```bash
terraform apply -target=aws_lambda_function.ai_log
```

### Destroy All Resources
```bash
terraform destroy
```

## Environment Variables

### Production Secrets
Set these in your CI/CD pipeline or AWS Secrets Manager:

```bash
export TF_VAR_github_token="ghp_..."
export TF_VAR_moodle_password="your_password"
```

## Troubleshooting

### Lambda Functions Not Responding
1. Check CloudWatch logs: `/aws/lambda/function_name`
2. Verify IAM role has correct permissions
3. Check DSQL database connectivity

### Moodle Not Accessible
1. Verify security group allows ports 80, 443, and 22
2. Check Elastic IP is associated
3. SSH to instance: `ssh -i ~/.ssh/moodle-key-pair.pem ec2-user@<IP>`

### API Gateway Errors
1. Check Lambda Function URLs
2. Verify CORS configuration
3. Review API Gateway CloudWatch logs: `/aws/apigateway/edulense-api`

### BuildSpec Issues
If Amplify build fails:
1. Check Flutter SDK installation
2. Verify correct repository and branch in variables
3. Review Amplify logs in console

## Cost Optimization

- **Lambda**: Pay per request, no charge when not used
- **DynamoDB**: Use `PAY_PER_REQUEST` for variable load
- **EC2**: Use `t3.micro` for Moodle (eligible for free tier)
- **S3**: Lifecycle policies to archive old objects
- **DSQL**: On-demand pricing, scales with usage

## Security Best Practices

1. **Never commit secrets**: Use `.gitignore` for `terraform.tfvars`
2. **Use IAM roles**: Lambda functions have minimal required permissions
3. **Enable MFA**: For AWS console access
4. **Restrict CORS**: In production, restrict to your domain
5. **Regular backups**: DSQL and DynamoDB have automatic backups
6. **Monitor**: CloudWatch alarms for errors and cost thresholds

## Monitoring and Logging

- **CloudWatch**: Lambda logs, API Gateway logs, ECS logs
- **CloudTrail**: All AWS API calls
- **X-Ray**: Lambda trace collection (optional)
- **Alarms**: Can be added via Terraform

## Next Steps

1. **Deploy**: Follow Setup Instructions above
2. **Test APIs**: Use the output URLs to test endpoints
3. **Configure Moodle**: Access Moodle plugin setup
4. **Deploy Frontend**: Amplify handles automatic deployment
5. **Monitor**: Check CloudWatch for errors and performance

## Support

For issues or questions:
1. Check Terraform logs: `export TF_LOG=DEBUG`
2. Review AWS console for resource details
3. Check CloudWatch logs for application errors
4. Review pull request artifacts for frontend build logs

## License

See LICENSE in root directory
