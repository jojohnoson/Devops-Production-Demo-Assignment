resource "aws_security_group" "alb" {
  name_prefix = "${var.project}-alb-"
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

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  tags = {
    Name = "${var.project}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "alb_main" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "svc" {
  for_each             = toset(["a", "b"])
  name                 = "${var.project}-${each.key}"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 10

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb_main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.svc["a"].arn
        weight = 50
      }
      target_group {
        arn    = aws_lb_target_group.svc["b"].arn
        weight = 50
      }
    }
  }
}

# Path rules: /a and /a/* go to service a, /b and /b/* go to service b
resource "aws_lb_listener_rule" "path" {
  for_each     = aws_lb_target_group.svc
  listener_arn = aws_lb_listener.http.arn
  priority     = each.key == "a" ? 10 : 20

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}", "/${each.key}/*"]
    }
  }
}