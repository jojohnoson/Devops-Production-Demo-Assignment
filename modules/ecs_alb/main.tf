resource "aws_security_group" "alb_sg" {
  name        = "demo-alb-sg"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "demo-ecs-instances-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "demo-ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "nginx_a" {
  name        = "tg-nginx-a"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check { path = "/" }
}

resource "aws_lb_target_group" "nginx_b" {
  name        = "tg-nginx-b"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check { path = "/" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_a.arn
  }
}

resource "aws_lb_listener_rule" "nginx_b_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_b.arn
  }
  condition {
    path_pattern { values = ["/b*"] }
  }
}

resource "aws_ecs_cluster" "cluster" {
  name = "demo-ecs-cluster"
}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "demo-ecs-lt-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = "t3.medium"
  iam_instance_profile { name = var.ec2_instance_profile_name }
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }
  user_data = base64encode("#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.cluster.name} >> /etc/ecs/ecs.config\n")
}

resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix         = "demo-ecs-asg-"
  vpc_zone_identifier = var.private_app_subnet_ids
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }
}

resource "aws_ecs_capacity_provider" "cp" {
  name = "demo-ecs-cp"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn
    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [aws_ecs_capacity_provider.cp.name]
}

resource "aws_ecs_task_definition" "nginx_a" {
  family                   = "nginx-a-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "256"
  execution_role_arn       = var.ecs_execution_role_arn
  container_definitions = jsonencode([{
    name      = "nginx-a"
    image     = "nginx:latest"
    essential = true
    portMappings = [{ containerPort = 80, hostPort = 0 }]
    command = ["/bin/sh", "-c", "echo 'Hello from Service NGINX-A!' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
  }])
}

resource "aws_ecs_task_definition" "nginx_b" {
  family                   = "nginx-b-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "256"
  execution_role_arn       = var.ecs_execution_role_arn
  container_definitions = jsonencode([{
    name      = "nginx-b"
    image     = "nginx:latest"
    essential = true
    portMappings = [{ containerPort = 80, hostPort = 0 }]
    command = ["/bin/sh", "-c", "echo 'Hello from Service NGINX-B!' > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'"]
  }])
}

resource "aws_ecs_service" "nginx_a" {
  name            = "nginx-a-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.nginx_a.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.cp.name
    weight            = 1
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_a.arn
    container_name   = "nginx-a"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "nginx_b" {
  name            = "nginx-b-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.nginx_b.arn
  desired_count   = 1
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.cp.name
    weight            = 1
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_b.arn
    container_name   = "nginx-b"
    container_port   = 80
  }
  depends_on = [aws_lb_listener.http]
}