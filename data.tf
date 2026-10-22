data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_ssm_parameter" "ecs_arm64_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}
