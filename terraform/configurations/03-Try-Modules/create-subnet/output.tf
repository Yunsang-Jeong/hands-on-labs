#
# 파일명 : ./create-subnet/output.tf
#

# Subnet을 만들때, for_each를 사용했기에 곧 바로 id를 output 할 수는 없습니다.
output "subnet" {
  description = "The object of subnet"
  value       = aws_subnet.this
}

output "route_table_igw" {
  description = "The id of internet-gateway"
  value       = aws_route_table.route_table_igw.id
}

# NAT-gateway로 외부 통신을 하는 route-table은 for_each를 사용했기에
# 곧 바로 id를 output 할 수는 없습니다.
output "route_table_nat" {
  description = "The object of NAT-gateway"
  value       = aws_route_table.route_table_nat
}