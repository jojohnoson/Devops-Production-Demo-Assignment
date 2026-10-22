output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "public_subnet_ids" {
  value       = [aws_subnet.pub_subnet-1.id, aws_subnet.pub_subnet-2.id]
  description = "The IDs of the public subnets"
}

output "app_subnet_ids" {
  value       = [aws_subnet.private_subnet-1.id, aws_subnet.private_subnet-2.id]
  description = "Private app subnet IDs (ECS EC2 instances)"
}

output "data_subnet_ids" {
  value       = [aws_subnet.private_subnet-3.id, aws_subnet.private_subnet-4.id]
  description = "Private data subnet IDs (isolated)"
}