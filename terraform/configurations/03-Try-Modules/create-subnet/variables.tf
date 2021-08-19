#
# 파일명 : ./create-subnet/variables.tf
#

# 해당 Module이 받아야 하는 값들을 정의합니다.
# 정의되지 않은 값들은 받을 수 없으며, 에러를 일으킵니다.
# default 속성이 정의된 경우 입력받지 않아도 에러가 발생하지 않습니다.

# Subnet을 생성할 VPC의 id입니다.
variable "vpc_id" {
  description = "The id of VPC"
  type        = string
}

# Internet-gateway의 id 입니다.
variable "igw_id" {
  description = "The id of internet-gateway"
  type        = string
  default     = ""
}

# 생성할 Subnet에 대한 값입니다.
variable "subnets" {
  description = "The subnet informations"
  type = list(object({
    identifier            = string
    availability_zone     = string
    cidr_block            = string
    create_nat            = bool
    enable_route_with_nat = bool
    enable_route_with_igw = bool
    name_tag_postfix      = string
  }))
}

# Name tag에 맞는 값을 지정합니다.
variable "name_tag_middle" {
  description = "Name tag"
  type        = string
}