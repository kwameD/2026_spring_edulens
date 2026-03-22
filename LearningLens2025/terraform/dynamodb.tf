# Optional: DynamoDB tables for high-speed data access
# These complement the DSQL database for specific use cases

# AI Log DynamoDB table - for fast logging and retrieval
resource "aws_dynamodb_table" "ai_log" {
  count = var.enable_dynamodb ? 1 : 0

  name           = "${var.project_name}-ai-log"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "session_id"
  range_key      = "timestamp"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # Secondary index for querying by user
  global_secondary_index {
    name            = "user_id-timestamp-index"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ai-log"
  })
}

# Game Data DynamoDB table - for leaderboards and scores
resource "aws_dynamodb_table" "game_data" {
  count = var.enable_dynamodb ? 1 : 0

  name           = "${var.project_name}-game-data"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "game_id"
  range_key      = "user_id"

  attribute {
    name = "game_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "score"
    type = "N"
  }

  # Global Secondary Index for querying scores by user
  global_secondary_index {
    name            = "user_id-score-index"
    hash_key        = "user_id"
    range_key       = "score"
    projection_type = "ALL"
  }

  attribute {
    name = "game_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-game-data"
  })
}

# Reflections DynamoDB table - for student reflections and feedback
resource "aws_dynamodb_table" "reflections" {
  count = var.enable_dynamodb ? 1 : 0

  name           = "${var.project_name}-reflections"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "reflection_id"
  range_key      = "created_at"

  attribute {
    name = "reflection_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "course_id"
    type = "S"
  }

  # Global Secondary Index for querying by user
  global_secondary_index {
    name            = "user_id-created_at-index"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # Global Secondary Index for querying by course
  global_secondary_index {
    name            = "course_id-created_at-index"
    hash_key        = "course_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "course_id"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = false
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-reflections"
  })
}

# IAM Policy to allow Lambda functions to access DynamoDB
data "aws_iam_policy_document" "lambda_dynamodb" {
  count = var.enable_dynamodb ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:DeleteItem",
    ]
    resources = [
      try(aws_dynamodb_table.ai_log[0].arn, ""),
      try(aws_dynamodb_table.game_data[0].arn, ""),
      try(aws_dynamodb_table.reflections[0].arn, ""),
      "${try(aws_dynamodb_table.ai_log[0].arn, "")}/*",
      "${try(aws_dynamodb_table.game_data[0].arn, "")}/*",
      "${try(aws_dynamodb_table.reflections[0].arn, "")}/*",
    ]
  }
}

resource "aws_iam_policy" "lambda_dynamodb" {
  count       = var.enable_dynamodb ? 1 : 0
  name        = "${var.project_name}-lambda-dynamodb"
  description = "Allow Lambda functions to access DynamoDB tables"
  policy      = data.aws_iam_policy_document.lambda_dynamodb[0].json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  count      = var.enable_dynamodb ? 1 : 0
  role       = aws_iam_role.lambda_token.name
  policy_arn = aws_iam_policy.lambda_dynamodb[0].arn
}
