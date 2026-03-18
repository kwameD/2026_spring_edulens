output "region" {
  description = "AWS region"
  value       = data.aws_region.current.region
}

output "amplify_app_id" {
  description = "Amplify app ID"
  value       = aws_amplify_app.edulenseweb.id
}

output "amplify_app_url" {
  description = "Amplify app URL"
  value       = aws_amplify_app.edulenseweb.default_domain
}

output "moodle_elastic_ip" {
  description = "Moodle instance public IP address"
  value       = aws_eip.lb.public_ip
}

output "moodle_ssh_key_path" {
  description = "Path to Moodle SSH private key"
  value       = local_sensitive_file.pem_file.filename
}

output "api_gateway_url" {
  description = "API Gateway base URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "lambda_ai_log_url" {
  description = "AI Log Lambda function URL"
  value       = aws_lambda_function_url.get_ai_log_url.function_url
}

output "lambda_game_data_url" {
  description = "Game Data Lambda function URL"
  value       = aws_lambda_function_url.get_game_data_url.function_url
}

output "lambda_code_eval_url" {
  description = "Code Evaluation Lambda function URL"
  value       = aws_lambda_function_url.code_eval_url.function_url
}

output "lambda_reflections_url" {
  description = "Reflections Lambda function URL"
  value       = aws_lambda_function_url.get_reflections_url.function_url
}

output "lambda_moodle_proxy_url" {
  description = "Moodle proxy Lambda function URL"
  value       = aws_lambda_function_url.get_moodle_proxy_url.function_url
}

output "s3_bucket_name" {
  description = "S3 bucket name for storage"
  value       = aws_s3_bucket.edulense.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for program grader"
  value       = aws_ecr_repository.edulense_program_grader.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.eval_code_cluster.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.eval_code_logs.name
}

output "dsql_cluster_identifier" {
  description = "DSQL cluster identifier"
  value       = aws_dsql_cluster.edulense.identifier
}

output "dsql_cluster_arn" {
  description = "DSQL cluster ARN"
  value       = aws_dsql_cluster.edulense.arn
}

output "dynamodb_ai_log_table" {
  description = "DynamoDB table for AI logs"
  value       = try(aws_dynamodb_table.ai_log[0].name, "Not configured")
}

output "dynamodb_game_data_table" {
  description = "DynamoDB table for game data"
  value       = try(aws_dynamodb_table.game_data[0].name, "Not configured")
}

output "dynamodb_reflections_table" {
  description = "DynamoDB table for reflections"
  value       = try(aws_dynamodb_table.reflections[0].name, "Not configured")
}

output "deployment_instructions" {
  description = "Deployment instructions"
  value       = <<-EOT
    
    ============ DEPLOYMENT COMPLETE ============
    
    1. Frontend (Flutter Web):
       - URL: ${aws_amplify_app.edulenseweb.default_domain}
    
    2. APIs:
       - AI Logs: ${aws_lambda_function_url.get_ai_log_url.function_url}
       - Game Data: ${aws_lambda_function_url.get_game_data_url.function_url}
       - Code Evaluation: ${aws_lambda_function_url.code_eval_url.function_url}
       - Reflections: ${aws_lambda_function_url.get_reflections_url.function_url}
       - Moodle Proxy: ${aws_lambda_function_url.get_moodle_proxy_url.function_url}
    
    3. Moodle LMS:
       - URL: http://${aws_eip.lb.public_ip}
       - SSH: ssh -i ${local_sensitive_file.pem_file.filename} ec2-user@${aws_eip.lb.public_ip}
    
    4. Code Evaluation:
       - ECS Cluster: ${aws_ecs_cluster.eval_code_cluster.name}
       - ECR Repository: ${aws_ecr_repository.edulense_program_grader.repository_url}
    
    5. Database:
       - DSQL Cluster: ${aws_dsql_cluster.edulense.identifier}
    
    6. Storage:
       - S3 Bucket: ${aws_s3_bucket.edulense.id}
    
    ============================================
  EOT
}
