#
# 파일명 : ./output.tf
#

output "vpc" {
  description = "The output of create-vpc module"
  value       = module.create_vpc
}

output "subnet" {
  description = "The output of create-subnet module"
  value       = module.create_subnet
}