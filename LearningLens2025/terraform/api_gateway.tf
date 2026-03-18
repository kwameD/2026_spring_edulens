# API Gateway REST API
resource "aws_api_gateway_rest_api" "edulense_api" {
  name        = "${var.project_name}-api"
  description = "API for EduLense LMS application"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api"
  })
}

# Request validator for API Gateway
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "${var.project_name}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.edulense_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

# ===================== AI_LOG Endpoint =====================
resource "aws_api_gateway_resource" "ai_log" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id
  parent_id   = aws_api_gateway_rest_api.edulense_api.root_resource_id
  path_part   = "ai-log"
}

resource "aws_api_gateway_method" "ai_log_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.ai_log.id
  http_method      = "POST"
  authorization    = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
}

resource "aws_api_gateway_integration" "ai_log_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.ai_log.id
  http_method      = aws_api_gateway_method.ai_log_post.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.ai_log.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_ai_log" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_log.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.edulense_api.execution_arn}/*/*"
}

# ===================== GAME_DATA Endpoint =====================
resource "aws_api_gateway_resource" "game_data" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id
  parent_id   = aws_api_gateway_rest_api.edulense_api.root_resource_id
  path_part   = "game-data"
}

resource "aws_api_gateway_method" "game_data_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.game_data.id
  http_method      = "POST"
  authorization    = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
}

resource "aws_api_gateway_method" "game_data_get" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.game_data.id
  http_method      = "GET"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "game_data_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.game_data.id
  http_method      = aws_api_gateway_method.game_data_post.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.game_data.invoke_arn
}

resource "aws_api_gateway_integration" "game_data_get" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.game_data.id
  http_method      = aws_api_gateway_method.game_data_get.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.game_data.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_game_data" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.game_data.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.edulense_api.execution_arn}/*/*"
}

# ===================== CODE_EVAL Endpoint =====================
resource "aws_api_gateway_resource" "code_eval" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id
  parent_id   = aws_api_gateway_rest_api.edulense_api.root_resource_id
  path_part   = "code-eval"
}

resource "aws_api_gateway_method" "code_eval_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.code_eval.id
  http_method      = "POST"
  authorization    = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
}

resource "aws_api_gateway_integration" "code_eval_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.code_eval.id
  http_method      = aws_api_gateway_method.code_eval_post.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.code_eval_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_code_eval" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.code_eval_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.edulense_api.execution_arn}/*/*"
}

# ===================== REFLECTIONS Endpoint =====================
resource "aws_api_gateway_resource" "reflections" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id
  parent_id   = aws_api_gateway_rest_api.edulense_api.root_resource_id
  path_part   = "reflections"
}

resource "aws_api_gateway_method" "reflections_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.reflections.id
  http_method      = "POST"
  authorization    = "NONE"
}

resource "aws_api_gateway_method" "reflections_get" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.reflections.id
  http_method      = "GET"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "reflections_post" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.reflections.id
  http_method      = aws_api_gateway_method.reflections_post.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.reflections.invoke_arn
}

resource "aws_api_gateway_integration" "reflections_get" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_resource.reflections.id
  http_method      = aws_api_gateway_method.reflections_get.http_method
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.reflections.invoke_arn
}

resource "aws_lambda_permission" "api_gateway_reflections" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reflections.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.edulense_api.execution_arn}/*/*"
}

# ===================== CORS Configuration =====================
resource "aws_api_gateway_method" "cors_simple" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_rest_api.edulense_api.root_resource_id
  http_method      = "OPTIONS"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "cors_simple" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_rest_api.edulense_api.root_resource_id
  http_method      = aws_api_gateway_method.cors_simple.http_method
  type             = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "cors_simple" {
  rest_api_id      = aws_api_gateway_rest_api.edulense_api.id
  resource_id      = aws_api_gateway_rest_api.edulense_api.root_resource_id
  http_method      = aws_api_gateway_method.cors_simple.http_method
  status_code      = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.cors_simple]
}

resource "aws_api_gateway_method_response" "cors_simple" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id
  resource_id = aws_api_gateway_rest_api.edulense_api.root_resource_id
  http_method = aws_api_gateway_method.cors_simple.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# ===================== Deployment =====================
resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id

  depends_on = [
    aws_api_gateway_integration.ai_log_post,
    aws_api_gateway_integration.game_data_post,
    aws_api_gateway_integration.game_data_get,
    aws_api_gateway_integration.code_eval_post,
    aws_api_gateway_integration.reflections_post,
    aws_api_gateway_integration.reflections_get,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.edulense_api.id
  stage_name    = var.environment

  tags = merge(var.tags, {
    Name = "${var.project_name}-api-${var.environment}"
  })

  depends_on = [aws_api_gateway_account.api]
}

# CloudWatch role for API Gateway
resource "aws_api_gateway_account" "api" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logs.arn
}

resource "aws_iam_role" "api_gateway_logs" {
  name = "${var.project_name}-api-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_logs" {
  name = "${var.project_name}-api-logs"
  role = aws_iam_role.api_gateway_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-api"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_api_gateway_method_settings" "prod" {
  rest_api_id = aws_api_gateway_rest_api.edulense_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    logging_level     = "INFO"
    data_trace_enabled = true
  }
}
