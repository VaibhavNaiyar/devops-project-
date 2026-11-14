# ---------- Container registry ----------
resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = "IMMUTABLE" # a released tag can never be overwritten
  force_delete         = true        # lets terraform destroy remove it with images inside

  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 15 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 15 }
      action       = { type = "expire" }
    }]
  })
}

# ---------- Database ----------
resource "aws_dynamodb_table" "requests" {
  name         = "${var.project}-requests"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
  server_side_encryption {
    enabled = true
  }
  point_in_time_recovery {
    enabled = true
  }
}

# ---------- Release configuration shared with Jenkins (SSM Parameter Store) ----------
locals {
  release_params = {
    ecr_repo_url     = aws_ecr_repository.app.repository_url
    target_group_arn = aws_lb_target_group.app.arn
    alb_dns          = aws_lb.app.dns_name
    table_name       = aws_dynamodb_table.requests.name
    region           = var.region
  }
}

resource "aws_ssm_parameter" "release" {
  for_each = local.release_params
  name     = "/${var.project}/${each.key}"
  type     = "String"
  value    = each.value
}

# Tag currently live in production; written by Jenkins after a successful smoke test, used for rollback
resource "aws_ssm_parameter" "live_tag" {
  name  = "/${var.project}/live_tag"
  type  = "String"
  value = "none"
  lifecycle {
    ignore_changes = [value]
  }
}
