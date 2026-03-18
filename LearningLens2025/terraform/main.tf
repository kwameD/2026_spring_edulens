# Provider and terraform configuration is in locals.tf

data "aws_ami" "moodle" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-moodle-4.5.6-r03-debian-12-amd64"]
  }

  owners = ["979382823631"]
}

resource "tls_private_key" "moodle-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "moodle-key-pair" {
  key_name   = "moodle-key-pair"
  public_key = tls_private_key.moodle-key.public_key_openssh
}

resource "aws_instance" "moodle_instance" {
  ami           = data.aws_ami.moodle.id
  instance_type = "t3.micro"
  tags = {
    Name = "SWEN670 Moodle Instance"
  }
  vpc_security_group_ids = [aws_security_group.moodle_security_group.id]
  key_name               = aws_key_pair.moodle-key-pair.key_name
}

resource "aws_eip" "lb" {
  instance = aws_instance.moodle_instance.id
  domain   = "vpc"
}

resource "local_sensitive_file" "pem_file" {
  filename             = pathexpand("~/.ssh/${aws_key_pair.moodle-key-pair.key_name}.pem")
  file_permission      = "600"
  directory_permission = "700"
  content              = tls_private_key.moodle-key.private_key_pem
}

resource "aws_security_group" "moodle_security_group" {
  name        = "moode-security-group"
  description = "Allow SSH, HTTP, HTTPS traffic"
  # Allow inbound traffic
  ingress {
    from_port   = 22 # SSH port
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }
  ingress {
    from_port   = 80 # HTTP port
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }
  ingress {
    from_port   = 443 # HTTPS port
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS from anywhere
  }
  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
}

# Variables are defined in variables.tf

resource "aws_amplify_app" "edulenseweb" {
  name                     = "EduLenseApp"
  repository               = "https://github.com/kwameD/2026_spring_edulens/"
  access_token             = var.github_token
  enable_branch_auto_build = true

  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - echo "Installing Flutter SDK"
            - git clone https://github.com/flutter/flutter.git -b stable --depth 1
            - export PATH="$PATH:$(pwd)/flutter/bin"
            - flutter config --no-analytics
            - flutter doctor
            - echo "Installing dependencies"
            - cd LearningLens2025/frontend/
            - flutter pub get
            - flutter create . --platforms web
        build:
          commands:
            - echo "Building Flutter web application"
            - |
              if [ -n "$ENV_FILE" ]; then
                printf '%s\n' "$ENV_FILE" > .env
              else
                : > .env
              fi
            - |
              {
                printf 'openai_apikey=%s\n' "$openai_apikey"
                printf 'MOODLE_USERNAME=%s\n' "$MOODLE_USERNAME"
                printf 'MOODLE_PASSWORD=%s\n' "$MOODLE_PASSWORD"
                printf 'MOODLE_URL=%s\n' "$MOODLE_URL"
                printf 'MOODLE_PROXY_URL=%s\n' "$MOODLE_PROXY_URL"
                printf 'claudeApiKey=%s\n' "$claudeApiKey"
                printf 'perplexity_apikey=%s\n' "$perplexity_apikey"
                printf 'grokKey=%s\n' "$grokKey"
                printf 'deepseek_apiKey=%s\n' "$deepseek_apiKey"
                printf 'GOOGLE_CLIENT_ID=%s\n' "$GOOGLE_CLIENT_ID"
                printf 'AI_LOGGING_URL=%s\n' "$AI_LOGGING_URL"
                printf 'CODE_EVAL_URL=%s\n' "$CODE_EVAL_URL"
                printf 'GAME_URL=%s\n' "$GAME_URL"
                printf 'REFLECTIONS_URL=%s\n' "$REFLECTIONS_URL"
                printf 'LOCAL_MODEL_DOWNLOAD_URL_PATH=%s\n' "$LOCAL_MODEL_DOWNLOAD_URL_PATH"
              } >> .env
            - unset ENV_FILE
            - flutter build web
      artifacts:
        baseDirectory: LearningLens2025/frontend/build/web/
        files:
          - '**/*'
          - '.env'
          - 'assets/.env'
    test:
      phases:
        test:
          commands:
            - echo "Exporting Artifacts"
      artifacts:
        baseDirectory: LearningLens2025/frontend/build/web/
        files:
          - '**/*'
          - '.env'
          - 'assets/.env'
    cache:
      paths:
        - flutter/.pub-cache
  EOT

  environment_variables = {
    ENV_FILE         = file("../frontend/.env")
    MOODLE_PROXY_URL = aws_lambda_function_url.get_moodle_proxy_url.function_url
  }
}

resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.edulenseweb.id
  branch_name = "team_e"

  stage = "PRODUCTION"
}

resource "aws_amplify_webhook" "deploy" {
  app_id      = aws_amplify_app.edulenseweb.id
  branch_name = aws_amplify_branch.master.branch_name
  description = "deployapp"
}

data "http" "deploy" {
  url = aws_amplify_webhook.deploy.url

  method = "POST"

  request_headers = {
    Accept = "application/json"
  }
}

output "response" {
  value = data.http.deploy.response_body
}

# AWS region data source is defined in locals.tf

resource "aws_ecr_repository" "edulense_program_grader" {
  name = "edulense-program-grader"
}

# Docker build provisioner commented out - requires Docker daemon running locally
# Uncomment and run after Docker is started, or build/push the image manually
# COMMAND TO BUILD DOCKER IMAGE MANUALLY:
# cd LearningLens2025/docker/
# bash dockerupload.sh
#
# resource "null_resource" "build_docker_image" {
#   triggers = {
#     script_hash = sha1(file("../docker/dockerupload.ps1"))
#     docker_hash = sha1(file("../docker/Dockerfile"))
#     runcode_hash = sha1(file("../docker/runcode.sh"))
#     evaluate = sha1(file("../docker/evaluate.py"))
#   }
#   provisioner "local-exec" {
#     working_dir = "../docker/"
#     command = "bash ./dockerupload.sh"
#     environment = {
#       AWS_REGION = data.aws_region.current.region
#       AWS_REPO_URL = aws_ecr_repository.edulense_program_grader.repository_url
#       AWS_REG_ID = aws_ecr_repository.edulense_program_grader.registry_id
#       AWS_NAME = aws_ecr_repository.edulense_program_grader.name
#     }
#   }
# }

resource "aws_dsql_cluster" "edulense" {
  deletion_protection_enabled = true

  tags = {
    Name = "EduLenseDatabaseCluster"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_token" {
  name               = "lambda_token_getter"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "db_ro" {
  statement {
    effect    = "Allow"
    actions   = ["dsql:DbConnectAdmin", "dsql:DbConnect"]
    resources = [aws_dsql_cluster.edulense.arn]
  }
}

resource "aws_iam_policy" "db_ro" {
  name   = "db_admin"
  policy = data.aws_iam_policy_document.db_ro.json
}

resource "aws_iam_role_policy_attachment" "db_lambda" {
  role       = aws_iam_role.lambda_token.name
  policy_arn = aws_iam_policy.db_ro.arn
}

resource "aws_iam_role_policy_attachment" "logging" {
  role       = aws_iam_role.lambda_token.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Run npm install before zipping
resource "null_resource" "npm_install_ai_log" {
  triggers = {
    # Trigger npm install when package.json or lock file changes
    package_json = filemd5("../lambda/ai_log/package.json")
    package_lock = filemd5("../lambda/ai_log/package-lock.json")
  }

  provisioner "local-exec" {
    command = "cd ../lambda/ai_log && npm install"
  }
}

data "archive_file" "ai_log" {
  type        = "zip"
  source_dir  = "../lambda/ai_log"
  excludes    = ["../lambda/ai_log/ai_log.zip"]
  output_path = "../lambda/ai_log/ai_log.zip"

  depends_on = [null_resource.npm_install_ai_log]
}

data "archive_file" "zip_plugin" {
  type        = "zip"
  source_dir  = "../MoodlePlugin/learninglens"
  output_path = "../MoodlePlugin/learninglens.zip"
}

resource "aws_lambda_function" "ai_log" {
  filename         = data.archive_file.ai_log.output_path
  function_name    = "ai_log"
  role             = aws_iam_role.lambda_token.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.ai_log.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = "10"
  environment {
    variables = {
      ENVIRONMENT    = "production"
      LOG_LEVEL      = "info"
      AWS_DB_CLUSTER = format("%s.dsql.%s.on.aws", aws_dsql_cluster.edulense.identifier, data.aws_region.current.region)
    }
  }
}

resource "aws_lambda_function_url" "get_ai_log_url" {
  function_name      = aws_lambda_function.ai_log.function_name
  authorization_type = "NONE"
  cors {
    allow_methods = ["GET", "POST"]
    allow_origins = ["*"]
    allow_headers = ["content-type"]
  }
}

# Run npm install before zipping
resource "null_resource" "npm_install_game_data" {
  triggers = {
    # Trigger npm install when package.json or lock file changes
    package_json = filemd5("../lambda/game_data/package.json")
    package_lock = filemd5("../lambda/game_data/package-lock.json")
  }

  provisioner "local-exec" {
    command = "cd ../lambda/game_data && npm install"
  }
}

data "archive_file" "game_data" {
  type        = "zip"
  source_dir  = "../lambda/game_data"
  excludes    = ["../lambda/game_data/game_data.zip"]
  output_path = "../lambda/game_data/game_data.zip"

  depends_on = [null_resource.npm_install_game_data]
}

resource "aws_lambda_function" "game_data" {
  filename         = data.archive_file.game_data.output_path
  function_name    = "game_data"
  role             = aws_iam_role.lambda_token.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.game_data.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = "10"
  environment {
    variables = {
      ENVIRONMENT    = "production"
      LOG_LEVEL      = "info"
      AWS_DB_CLUSTER = format("%s.dsql.%s.on.aws", aws_dsql_cluster.edulense.identifier, data.aws_region.current.region)
    }
  }
}

resource "aws_lambda_function_url" "get_game_data_url" {
  function_name      = aws_lambda_function.game_data.function_name
  authorization_type = "NONE"
  cors {
    allow_methods = ["GET", "POST", "DELETE"]
    allow_origins = ["*"]
    allow_headers = ["content-type"]
  }
}

# Run npm install before zipping
resource "null_resource" "npm_install_reflections" {
  triggers = {
    # Trigger npm install when package.json or lock file changes
    package_json = filemd5("../lambda/reflections/package.json")
    package_lock = filemd5("../lambda/reflections/package-lock.json")
  }

  provisioner "local-exec" {
    command = "cd ../lambda/reflections && npm install"
  }
}

data "archive_file" "reflections" {
  type        = "zip"
  source_dir  = "../lambda/reflections"
  excludes    = ["../lambda/reflections/reflections.zip"]
  output_path = "../lambda/reflections/reflections.zip"

  depends_on = [null_resource.npm_install_reflections]
}

resource "aws_lambda_function" "reflections" {
  filename         = data.archive_file.reflections.output_path
  function_name    = "reflections"
  role             = aws_iam_role.lambda_token.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.reflections.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = "10"
  environment {
    variables = {
      ENVIRONMENT    = "production"
      LOG_LEVEL      = "info"
      AWS_DB_CLUSTER = format("%s.dsql.%s.on.aws", aws_dsql_cluster.edulense.identifier, data.aws_region.current.region)
    }
  }
}

resource "aws_lambda_function_url" "get_reflections_url" {
  function_name      = aws_lambda_function.reflections.function_name
  authorization_type = "NONE"
  cors {
    allow_methods = ["GET", "POST"]
    allow_origins = ["*"]
    allow_headers = ["content-type"]
  }
}

data "archive_file" "moodle_proxy" {
  type        = "zip"
  source_dir  = "../lambda/moodle_proxy"
  excludes    = ["../lambda/moodle_proxy/moodle_proxy.zip"]
  output_path = "../lambda/moodle_proxy/moodle_proxy.zip"
}

resource "aws_lambda_function" "moodle_proxy" {
  filename         = data.archive_file.moodle_proxy.output_path
  function_name    = "moodle_proxy"
  role             = aws_iam_role.lambda_token.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.moodle_proxy.output_base64sha256
  runtime          = "nodejs20.x"
  timeout          = "10"
  environment {
    variables = {
      MOODLE_URL = format("http://%s", aws_eip.lb.public_ip)
    }
  }
}

resource "aws_lambda_function_url" "get_moodle_proxy_url" {
  function_name      = aws_lambda_function.moodle_proxy.function_name
  authorization_type = "NONE"
  cors {
    allow_methods = ["GET", "POST"]
    allow_origins = ["*"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_lambda_permission" "moodle_proxy_function_url" {
  statement_id           = "AllowPublicInvokeMoodleProxyUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.moodle_proxy.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "moodle_proxy_function_url_invoke" {
  statement_id  = "AllowPublicInvokeMoodleProxyTf"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.moodle_proxy.function_name
  principal     = "*"
}
