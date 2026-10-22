output "dns_name" {
  value       = aws_lb.alb_main.dns_name
  description = "ALB DNS name"
}

output "alb_sg_id" {
  value       = aws_security_group.alb.id
  description = "ALB security group ID (the ECS EC2 SG allows traffic from this)"
}

output "target_group_arns" {
  value       = { for k, v in aws_lb_target_group.svc : k => v.arn }
  description = "Target group ARNs keyed by service (a, b)"
}