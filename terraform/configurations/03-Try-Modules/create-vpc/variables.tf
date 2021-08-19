#
# 파일명 : ./create-vpc/variables.tf
#

# 해당 Module이 받아야 하는 값들을 정의합니다.
# 정의되지 않은 값들은 받을 수 없으며, 에러를 일으킵니다.
# default 속성이 정의된 경우 입력받지 않아도 에러가 발생하지 않습니다.

# vpc를 생성을 결정합니다.
variable "create_vpc" {
  description = "If true, it will create vpc"
  type        = bool
  default     = true
}

# vpc_cidr 값을 지정합니다.
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}

# Internet-gateway 생성을 결정합니다.
variable "create_igw" {
  description = "If true, it will create internet-gateway"
  type        = bool
}

# Name tag에 맞는 값을 지정합니다.
variable "name_tag_middle" {
  description = "Name tag"
  type        = string
}