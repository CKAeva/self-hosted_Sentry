
# ALB section
resource "aws_lb" "alb" {
  name               = "tera-${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [var.alb_sg_id]

  subnets = values(var.public_subnet_ids)

  enable_deletion_protection = var.enable_deletion_protection

  idle_timeout = var.alb_idle_timeout

  tags = {
    Name        = "tera-${var.project_name}-alb"
    Environment = var.env_name
  }
}

# target group section
resource "aws_lb_target_group" "tg" {
  name        = "tera-${var.project_name}-tg"
  port        = 9000
  protocol    = "HTTP"
  target_type = "instance"

  vpc_id = var.vpc_id

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "tera-${var.project_name}-tg"
    Environment = var.env_name
  }
}

# target group attachment
resource "aws_lb_target_group_attachment" "private" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = var.private_instance_id
  port             = 9000
}

# listener section
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn

  port     = 443
  protocol = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Invalid host header"
      status_code  = "404"
    }
  }

  tags = {
    Name        = "tera-${var.project_name}-https-listener"
    Environment = var.env_name
  }
}

# listener host_header

resource "aws_lb_listener_rule" "host_header_rule" {
  listener_arn = aws_lb_listener.https.arn

  priority = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    host_header {
      values = [var.host_header]
    }
  }

  tags = {
    Name        = "tera-${var.project_name}-host-header-rule"
    Environment = var.env_name
  }
}
