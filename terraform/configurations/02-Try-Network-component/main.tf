#
# 파일명 : main.tf
#

# VPC(10.0.0.0/16)을 하나 생성합니다.
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  tags = {
      "Name" = "vpc-an2-mytf-prod"
  }
}

# Internet-gateway를 생성하고 위에서 생성한 VPC에 연결합니다.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
  tags   = {
      "Name" = "igw-an2-mytf-prod"
  }
}

# Subnet(10.0.0.0/24)를 A-Zone에 하나 생성합니다.
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
  availability_zone = "ap-northeast-2a"
  cidr_block        = "10.0.0.0/24"
  tags = {
      "Name" = "sub-an2-mytf-prod-pub-a"
  }
}

# Subnet(10.0.64.0/24)를 C-Zone에 하나 생성합니다.
resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
  availability_zone = "ap-northeast-2c"
  cidr_block        = "10.0.64.0/24"
  tags = {
      "Name" = "sub-an2-mytf-prod-pub-c"
  }
}

# 외부 통신을 Internet-gateway를 거치도록 Route-table을 생성합니다.
resource "aws_route_table" "rt" {
  vpc_id       = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id  # 생성된 리소스에서 internet-gw id를 읽어옵니다.
  }
  tags         = {
      "Name" = "rt-an2-mytf-prod-pub"
  }
}

# 생성한 Route-table에 Subnet을 연결합니다.
resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id # 생성된 리소스에서 subnet id를 읽어옵니다.
  route_table_id = aws_route_table.rt.id # 생성된 리소스에서 route-table id를 읽어옵니다.
}

# 생성한 Route-table에 Subnet을 연결합니다.
resource "aws_route_table_association" "subnet2" {
  subnet_id      = aws_subnet.subnet2.id # 생성된 리소스에서 subnet id를 읽어옵니다.
  route_table_id = aws_route_table.rt.id # 생성된 리소스에서 route-table id를 읽어옵니다.
}


# # Subnet(10.0.128.0/24)를 A-Zone에 하나 생성합니다.
# resource "aws_subnet" "subnet3" {
#   vpc_id            = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
#   availability_zone = "ap-northeast-2a"
#   cidr_block        = "10.0.128.0/24"
#   tags = {
#       "Name" = "sub-an2-mytf-prod-pri-a"
#   }
# }

# # Subnet(10.0.192.0/24)를 C-Zone에 하나 생성합니다.
# resource "aws_subnet" "subnet4" {
#   vpc_id            = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
#   availability_zone = "ap-northeast-2c"
#   cidr_block        = "10.0.192.0/24"
#   tags = {
#       "Name" = "sub-an2-mytf-prod-pri-c"
#   }
# }

# # NAT 게이트웨이를 subnet1(Public)에 생성합니다.
# resource "aws_nat_gateway" "this" {
#   subnet_id     = aws_subnet.subnet1.id
#   allocation_id = aws_eip.nat.id
#   tags = {
#     "Name" = "nat-an2-mytf-prod-a"
#   }
# }

# # NAT 게이트웨이를 위해 EIP를 하나 생성합니다.
# resource "aws_eip" "nat" {
#   vpc      = true
#   tags = {
#     "Name" = "eip-an2-mytf-prod-nat"
#   }
# }

# # 외부 통신을 NAT 게이트웨이를 거치도록 Route-table을 생성합니다.
# resource "aws_route_table" "rt2" {
#   vpc_id       = aws_vpc.this.id # 생성된 리소스에서 vpc id를 읽어옵니다.
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_nat_gateway.this.id  # 생성된 리소스에서 NAT 게이트웨이 id를 읽어옵니다.
#   }
#   tags         = {
#       "Name" = "rt-an2-mytf-prod-pri"
#   }
# }

# # 생성한 Route-table에 Subnet을 연결합니다.
# resource "aws_route_table_association" "subnet3" {
#   subnet_id      = aws_subnet.subnet3.id # 생성된 리소스에서 subnet id를 읽어옵니다.
#   route_table_id = aws_route_table.rt2.id # 생성된 리소스에서 route-table id를 읽어옵니다.
# }

# # 생성한 Route-table에 Subnet을 연결합니다.
# resource "aws_route_table_association" "subnet4" {
#   subnet_id      = aws_subnet.subnet4.id # 생성된 리소스에서 subnet id를 읽어옵니다.
#   route_table_id = aws_route_table.rt2.id # 생성된 리소스에서 route-table id를 읽어옵니다.
# }