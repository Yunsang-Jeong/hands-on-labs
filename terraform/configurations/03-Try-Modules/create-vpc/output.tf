#
# 파일명 : ./create-vpc/output.tf
#

output "vpc_id" {
  description = "The id of vpc"
  value       = var.create_vpc ? aws_vpc.this[0].id : ""
}

output "igw_id" {
  description = "The id of internet-gateway"
  value       = var.create_vpc && var.create_igw ? aws_internet_gateway.this[0].id : ""
}