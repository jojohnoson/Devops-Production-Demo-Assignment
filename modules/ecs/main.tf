data "aws_region" "current" {}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

locals {
  services = { a = "nginx-a", b = "nginx-b" }
}

resource "aws_ecs_cluster" "main" {
  name = var.project

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = var.log_group_name
  retention_in_days = 7
}


resource "aws_security_group" "ecs_ec2" {
  name   = "${var.project}-ecs-ec2-sg"
  vpc_id = var.vpc_id

  ingress {
    description     = "Dynamic container ports from the ALB only"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "ecs" {
  name_prefix            = "${var.project}-ecs-"
  image_id               = data.aws_ssm_parameter.ecs_ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ecs_ec2.id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode("#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config\n")

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project}-ecs-node" }
  }
}

resource "aws_autoscaling_group" "ecs" {
  name                  = "${var.project}-ecs-asg"
  min_size              = 2
  max_size              = 4
  desired_capacity      = 2
  vpc_zone_identifier   = var.app_subnet_ids
  protect_from_scale_in = false

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_task_definition" "nginx" {
  for_each                 = local.services
  family                   = "${var.project}-${each.value}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.task_execution_role_arn

  container_definitions = jsonencode([{
    name       = "nginx"
    image      = "nginx:1.27-alpine"
    essential  = true
    cpu        = 128
    memory     = 256
    entryPoint = ["/bin/sh", "-c"]
    command = [
      "mkdir -p /usr/share/nginx/html/${each.key} && echo '<h1>Hello from ${each.value}</h1>' | tee /usr/share/nginx/html/index.html > /usr/share/nginx/html/${each.key}/index.html && exec nginx -g 'daemon off;'"
    ]
    portMappings = [{
      containerPort = 80
      hostPort      = 0
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = each.value
      }
    }
  }])

  depends_on = [aws_cloudwatch_log_group.ecs]
}

resource "aws_ecs_service" "nginx" {
  for_each                          = local.services
  name                              = each.value
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.nginx[each.key].arn
  desired_count                     = 2
  health_check_grace_period_seconds = 30

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  load_balancer {
    target_group_arn = var.target_group_arns[each.key]
    container_name   = "nginx"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}

resource "aws_appautoscaling_target" "svc" {
  for_each           = local.services
  min_capacity       = 2
  max_capacity       = 4
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.nginx[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each           = local.services
  name               = "${var.project}-cpu-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.svc[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.svc[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.svc[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}