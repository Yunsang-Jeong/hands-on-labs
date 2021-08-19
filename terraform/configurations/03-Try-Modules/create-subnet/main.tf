#
# 파일명 : ./create-subnet/main.tf
#

# Subnet을 생성합니다.
resource "aws_subnet" "this" {
	# 동일한 리소스를 여러번 생성하는 경우 count 혹은 for_each를 사용할 수 있습니다.
  # for_each의 경우, Key-Value 쌍의 Dictionary 타입을 입력받습니다.
  # 각각의 Loop에서 key는 'each.key'로 참조하며, value는 'each.value.<속성명>'으로 참조합니다.
  for_each          = { for subnet in var.subnets : subnet.identifier => subnet }
  vpc_id            = var.vpc_id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block
  tags = {
    "Name" = "igw-${var.name_tag_middle}-${each.value.name_tag_postfix}"
  }
}

# Internet-gateway로 외부 통신을 하는 route-table을 생성합니다.
resource "aws_route_table" "route_table_igw" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
  tags = {
    "Name" = "rt-${var.name_tag_middle}-igw"
  }
}

# Subnet 중, enable_route_with_igw가 true인 것에 대해서 route-table 연결 작업을 합니다.
resource "aws_route_table_association" "route_table_igw" {
  for_each       = { 
		for subnet in var.subnets : subnet.identifier => subnet if subnet.enable_route_with_igw == true 
	}
  subnet_id      = lookup(aws_subnet.this, each.value.identifier).id
  route_table_id = aws_route_table.route_table_igw.id
}

# NAT-gateway를 생성합니다.
resource "aws_nat_gateway" "this" {
  for_each      = { 
		for subnet in var.subnets : subnet.identifier => subnet if subnet.create_nat == true 
	}
  subnet_id     = lookup(aws_subnet.this, each.value.identifier).id
  allocation_id = lookup(aws_eip.this, each.value.identifier).id
  tags = {
    "Name" = "nat-${var.name_tag_middle}-${each.value.name_tag_postfix}"
  }
}

# NAT-gateway를 위한 EIP를 생성합니다.
resource "aws_eip" "this" {
  for_each = { 
		for subnet in var.subnets : subnet.identifier => subnet if subnet.create_nat == true 
	}
  vpc      = true
  tags     = {
    "Name" = "eip-${var.name_tag_middle}-nat-${each.value.name_tag_postfix}"
  }
}

# NAT-gateway로 외부 통신을 하는 route-table을 생성합니다.
resource "aws_route_table" "route_table_nat" {
  for_each = { 
		for subnet in var.subnets : subnet.identifier => subnet if subnet.create_nat == true 
	}
  vpc_id   = var.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = lookup(aws_nat_gateway.this, each.value.identifier).id
  }
  tags     = {
    "Name" = "rt-${var.name_tag_middle}-nat-${each.value.name_tag_postfix}"
  }
}

# AZ별 NAT-gateway로 외부 통신을 하는 route-table 목록을 생성합니다.
locals {
  route_table_nat_by_az = transpose({
    for identifier in keys(aws_route_table.route_table_nat) : lookup(aws_route_table.route_table_nat, identifier).id => [lookup(aws_subnet.this, identifier).availability_zone]
  })
}

# Subnet 중, enable_route_with_nat가 true인 것에 대해서 route-table 연결 작업을 합니다.
# 동일 AZ의 NAT-gateway로 연결되는 Route-table이 있다면, 우선적으로 연결됩니다.
# 없다면, 타 AZ의 NAT-gateway로 연결되는 Route-table로 연결됩니다.
resource "aws_route_table_association" "route_table_nat" {
  for_each       = { 
		for subnet in var.subnets : subnet.identifier => subnet if subnet.enable_route_with_nat == true && length(aws_nat_gateway.this) > 0
	}
  subnet_id      = lookup(aws_subnet.this, each.key).id
  route_table_id = can(local.route_table_nat_by_az[each.value.availability_zone]) ? lookup(local.route_table_nat_by_az, each.value.availability_zone)[0] : flatten(values(local.route_table_nat_by_az))[0]
}