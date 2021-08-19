#
# 파일명 : output.tf
#

# Terraform의 plan, apply 과정에서 콘솔에 출력되는 값 입니다.
# 다양한 모듈을 사용하고 있다면, 해당 모듈의 출력값으로 참조가 가능합니다.

output "vpc_id" {
  description = "The id of the VPC"
  value       = aws_vpc.this.id
}

output "igw_gateway_id" {
  description = "The id of the internet gateway"
  value       = aws_internet_gateway.this.id
}

output "subnet1" {
  description = "The id of the subnet 1"
  value       = aws_subnet.subnet1.id
}

output "subnet2" {
  description = "The id of the subnet 2"
  value       = aws_subnet.subnet2.id
}

output "route-table-igw" {
  description = "The id of the route table for igw"
  value       = aws_route_table.rt.id
}

# output "subnet3" {
#   description = "The id of the subnet 3"
#   value       = aws_subnet.subnet3.id
# }

# output "subnet4" {
#   description = "The id of the subnet 4"
#   value       = aws_subnet.subnet4.id
# }

# output "route-table-nat" {
#   description = "The id of the route table for NAT"
#   value       = aws_route_table.rt2.id
# }