[toc]

# 0. !!

본 실습은 다음의 조건들이 필요합니다.

- 기본적인 AWS 지식(AWS VPC, Subnet, Internet-gateway, NAT-gateway, Route-table)
- 기본적인 Shell 사용 능력(`cd`, `pwd`, `mkdir`, `tree`, 등)
- Terrafrom CLI와 AWS CLI가 설치된 환경
- `Terraform : Try 1 - AWS network component` 진행 및 이해

Terraform을 활용하여 서울리전에 다음의 AWS 인프라를 순차적으로 생성하는 실습입니다.

- VPC (1)
- Subnets (Public2, Private2)
- Internet-gateway (1)
- NAT-gateway, EIP (1)
- Route-table (2)

# 1. 디렉토리 생성

임의의 디렉토리를 하나 생성하고 해당 경로에 쉘 프로그램을 실행시킵니다.

```bash
$ mkdir -p /Users/yunsang/Desktop/my-tf2
$ cd /Users/yunsang/Desktop/my-tf2
```

# 2. Terraform 코드 작성 : Root module 작성

생성한 디렉토리에 다음과 같이 코드를 작성 및 파일로 저장합니다.

```hcl
#
# 파일명 : ./provider.tf
#

provider "aws" {
  region  = "ap-northeast-2"
  profile = "default"
}
```

```hcl
#
# 파일명 : ./main.tf
#

# 반복되거나 전체적으로 적용되는 내용 혹은 전처리가 필요한 내용을 local block에 정의합니다.
locals {
  name_tag_middle = "an2-mytf-prod"
}

# VPC를 생성하는 Module을 호출하면서 입력값들을 넘깁니다.
module "create_vpc" {
	# Module이 존재하는 경로입니다. 절대, 상대 경로 혹은 Git 등이 될 수 있습니다.
  source          = "./create-vpc/" 

	# 다음은 해당 Module에서 variable block으로 요구하는 값들 입니다.
  vpc_cidr        = "10.0.0.0/16"
  create_igw      = true
  name_tag_middle = local.name_tag_middle # local block에 저장된 값을 참조합니다.
}

# 이렇게 local block은 어디에는 반복적으로 사용할 수 있습니다.
locals {
  # create_vpc Module에서 output block으로 vpc_id 값을 id로 출력해주고 있고 이를 vpc_id로 저장
  vpc_id = module.create_vpc.vpc_id
  # create_vpc Module에서 output block으로 igw_id 값을 id로 출력해주고 있고 이를 igw_id로 저장
  igw_id = module.create_vpc.igw_id
}

# Subnet를 생성하는 Module을 호출하면서 입력값들을 넘깁니다.
module "create_subnet" {
	# Module이 존재하는 경로입니다. 절대, 상대 경로 혹은 Git 등이 될 수 있습니다.
  source          = "./create-subnet/"

	# 다음은 해당 Module에서 variable block으로 요구하는 값들 입니다.
  vpc_id        = local.vpc_id # local block에 저장된 값을 참조합니다.
  igw_id        = local.igw_id # local block에 저장된 값을 참조합니다.
  subnets       = [
    {
      identifier            = "public-a"
      name_tag_postfix      = "pub-a"
      availability_zone     = "ap-northeast-2a"
      cidr_block            = "10.0.0.0/24"
      enable_route_with_igw = true # Public Subnet 이므로 Internet-gateway를 사용합니다.
			enable_route_with_nat = false
      create_nat            = true # NAT-gateway를 해당 Subnet에 생성합니다.
    },
    {
      identifier            = "public-c"
      name_tag_postfix      = "pub-c"
      availability_zone     = "ap-northeast-2c"
      cidr_block            = "10.0.64.0/24"
      enable_route_with_igw = true # Public Subnet 이므로 Internet-gateway를 사용합니다.
			enable_route_with_nat = false
      create_nat            = false
    },
    {
      identifier            = "private-a"
      name_tag_postfix      = "pri-a"
      availability_zone     = "ap-northeast-2a"
      cidr_block            = "10.0.128.0/24"
      enable_route_with_igw = false 
			enable_route_with_nat = true # Privaate Subnet 이므로 NAT-gateway를 사용합니다.
      create_nat            = false
    },
    {
      identifier            = "private-c"
      name_tag_postfix      = "pri-c"
      availability_zone     = "ap-northeast-2c"
      cidr_block            = "10.0.192.0/24"
      enable_route_with_igw = false
			enable_route_with_nat = true # Privaate Subnet 이므로 NAT-gateway를 사용합니다.
      create_nat            = false
    }
  ]
  name_tag_middle = local.name_tag_middle # local block에 저장된 값을 참조합니다.
}
```

```hcl
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
```

# 3. Terraform 코드 작성 : create-vpc module 작성

Module 작성을 위한 디렉토리를 생성 후, 해당 디렉토리에 코드를 작성 및 파일로 저장합니다.

```bash
$ pwd
/Users/yunsang/Desktop/my-tf2
$ mkdir create-vpc
```

```hcl
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
```

```hcl
#
# 파일명 : ./create-vpc/main.tf
#

resource "aws_vpc" "this" {
	# 동일한 리소스를 여러번 생성하는 경우 count 혹은 for_each를 사용할 수 있습니다.
  # 아래 코드는 이를 응용한 기법으로, var.create_vpc가 true인 경우에만 vpc가 생성됩니다.
  count      = var.create_vpc ? 1 : 0
  cidr_block = var.vpc_cidr
  tags       = {
      "Name" = "vpc-${var.name_tag_middle}"
  }
}

resource "aws_internet_gateway" "this" {
  # vpc가 만들어져 있고, igw를 만들어야 된다면 동작합니다.
  count  = var.create_vpc && var.create_igw ? 1 : 0
  # count로 생성된 리소스들은 리스트의 아이템을 인덱싱 하듯 대괄호를 통해 지정해야 합니다.
	vpc_id = aws_vpc.this[0].id
  tags   = {
      "Name" = "igw-${var.name_tag_middle}"
  }
}
```

```hcl
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
```

# 4. Terraform 코드 작성 : create-subnet module 작성

Module 작성을 위한 디렉토리를 생성 후, 해당 디렉토리에 코드를 작성 및 파일로 저장합니다.

```bash
$ pwd
/Users/yunsang/Desktop/my-tf2
$ mkdir create-subnet
```

```hcl
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
```

```hcl
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
```

```hcl
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
```

# 5. 중간점검

현재까지 잘 따라 왔다면, 디렉토리 구조는 다음과 같습니다.

```bash
$ tree /Users/yunsang/Desktop/my-tf2
/Users/yunsang/Desktop/my-tf2
├── create-subnet
│   ├── main.tf
│   ├── output.tf
│   └── variables.tf
├── create-vpc
│   ├── main.tf
│   ├── output.tf
│   └── variables.tf
├── main.tf
├── output.tf
└── provider.tf
```

# 6. Terraform init

```bash
$ terraform init

Initializing modules...

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v3.26.0...
- Installed hashicorp/aws v3.26.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

`Terraform Hands-on : Try 1`과 달리 `.terraform` 안에 modules 라는 디렉토리가 추가로 생성되었습니다.

```bash
$ tree .terraform
.terraform
├── modules
│   └── modules.json
└── providers
    └── registry.terraform.io
        └── hashicorp
            └── aws
                └── 3.26.0
                    └── darwin_amd64
                        └── terraform-provider-aws_v3.26.0_x5

7 directories, 2 files
```

modules.json의 파일 내용을 보면 module에 대한 경로가 명시되어 있습니다. Module이 저장된 폴더의 이름 혹은 경로가 수정되거나 Root Module 안에서 Module의 이름이 달라진다면 다시 한번 `terrafrom init`을 수행하도록 요구하니 주의합니다.

```json
{
    "Modules": [{
        "Key": "create_vpc",
        "Source": "./create-vpc/",
        "Dir": "create-vpc"
    }, {
        "Key": "",
        "Source": "",
        "Dir": "."
    }, {
        "Key": "create_subnet",
        "Source": "./create-subnet/",
        "Dir": "create-subnet"
    }]
}
```

만일, 외부 저장소(Git)을 사용한 경우 전체 module 코드가 다운로드됩니다.

# 7. Terraform plan

```bash
$ terraform plan

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.create_subnet.aws_eip.this["public-a"] will be created
  + resource "aws_eip" "this" {
      + allocation_id        = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = (known after apply)
      + id                   = (known after apply)
      + instance             = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + tags                 = {
          + "Name" = "eip-an2-mytf-prod-nat-pub-a"
        }
      + vpc                  = true
    }

  # module.create_subnet.aws_nat_gateway.this["public-a"] will be created
  + resource "aws_nat_gateway" "this" {
      + allocation_id        = (known after apply)
      + id                   = (known after apply)
      + network_interface_id = (known after apply)
      + private_ip           = (known after apply)
      + public_ip            = (known after apply)
      + subnet_id            = (known after apply)
      + tags                 = {
          + "Name" = "nat-an2-mytf-prod-pub-a"
        }
    }

  # module.create_subnet.aws_route_table.route_table_igw will be created
  + resource "aws_route_table" "route_table_igw" {
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + cidr_block                = "0.0.0.0/0"
              + egress_only_gateway_id    = ""
              + gateway_id                = (known after apply)
              + instance_id               = ""
              + ipv6_cidr_block           = ""
              + local_gateway_id          = ""
              + nat_gateway_id            = ""
              + network_interface_id      = ""
              + transit_gateway_id        = ""
              + vpc_endpoint_id           = ""
              + vpc_peering_connection_id = ""
            },
        ]
      + tags             = {
          + "Name" = "rt-an2-mytf-prod-igw"
        }
      + vpc_id           = (known after apply)
    }

  # module.create_subnet.aws_route_table.route_table_nat["public-a"] will be created
  + resource "aws_route_table" "route_table_nat" {
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + route            = [
          + {
              + cidr_block                = "0.0.0.0/0"
              + egress_only_gateway_id    = ""
              + gateway_id                = ""
              + instance_id               = ""
              + ipv6_cidr_block           = ""
              + local_gateway_id          = ""
              + nat_gateway_id            = (known after apply)
              + network_interface_id      = ""
              + transit_gateway_id        = ""
              + vpc_endpoint_id           = ""
              + vpc_peering_connection_id = ""
            },
        ]
      + tags             = {
          + "Name" = "rt-an2-mytf-prod-nat-pub-a"
        }
      + vpc_id           = (known after apply)
    }

  # module.create_subnet.aws_route_table_association.route_table_igw["public-a"] will be created
  + resource "aws_route_table_association" "route_table_igw" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.create_subnet.aws_route_table_association.route_table_igw["public-c"] will be created
  + resource "aws_route_table_association" "route_table_igw" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.create_subnet.aws_route_table_association.route_table_nat["private-a"] will be created
  + resource "aws_route_table_association" "route_table_nat" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.create_subnet.aws_route_table_association.route_table_nat["private-c"] will be created
  + resource "aws_route_table_association" "route_table_nat" {
      + id             = (known after apply)
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.create_subnet.aws_subnet.this["private-a"] will be created
  + resource "aws_subnet" "this" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = false
      + availability_zone               = "ap-northeast-2a"
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.0.128.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = false
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "igw-an2-mytf-prod-pri-a"
        }
      + vpc_id                          = (known after apply)
    }

  # module.create_subnet.aws_subnet.this["private-c"] will be created
  + resource "aws_subnet" "this" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = false
      + availability_zone               = "ap-northeast-2c"
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.0.192.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = false
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "igw-an2-mytf-prod-pri-c"
        }
      + vpc_id                          = (known after apply)
    }

  # module.create_subnet.aws_subnet.this["public-a"] will be created
  + resource "aws_subnet" "this" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = false
      + availability_zone               = "ap-northeast-2a"
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.0.0.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = false
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "igw-an2-mytf-prod-pub-a"
        }
      + vpc_id                          = (known after apply)
    }

  # module.create_subnet.aws_subnet.this["public-c"] will be created
  + resource "aws_subnet" "this" {
      + arn                             = (known after apply)
      + assign_ipv6_address_on_creation = false
      + availability_zone               = "ap-northeast-2c"
      + availability_zone_id            = (known after apply)
      + cidr_block                      = "10.0.64.0/24"
      + id                              = (known after apply)
      + ipv6_cidr_block_association_id  = (known after apply)
      + map_public_ip_on_launch         = false
      + owner_id                        = (known after apply)
      + tags                            = {
          + "Name" = "igw-an2-mytf-prod-pub-c"
        }
      + vpc_id                          = (known after apply)
    }

  # module.create_vpc.aws_internet_gateway.this[0] will be created
  + resource "aws_internet_gateway" "this" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + tags     = {
          + "Name" = "igw-an2-mytf-prod"
        }
      + vpc_id   = (known after apply)
    }

  # module.create_vpc.aws_vpc.this[0] will be created
  + resource "aws_vpc" "this" {
      + arn                              = (known after apply)
      + assign_generated_ipv6_cidr_block = false
      + cidr_block                       = "10.0.0.0/16"
      + default_network_acl_id           = (known after apply)
      + default_route_table_id           = (known after apply)
      + default_security_group_id        = (known after apply)
      + dhcp_options_id                  = (known after apply)
      + enable_classiclink               = (known after apply)
      + enable_classiclink_dns_support   = (known after apply)
      + enable_dns_hostnames             = (known after apply)
      + enable_dns_support               = true
      + id                               = (known after apply)
      + instance_tenancy                 = "default"
      + ipv6_association_id              = (known after apply)
      + ipv6_cidr_block                  = (known after apply)
      + main_route_table_id              = (known after apply)
      + owner_id                         = (known after apply)
      + tags                             = {
          + "Name" = "vpc-an2-mytf-prod"
        }
    }

Plan: 14 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + subnet = {
      + route_table_igw = (known after apply)
      + route_table_nat = {
          + public-a = {
              + id               = (known after apply)
              + owner_id         = (known after apply)
              + propagating_vgws = (known after apply)
              + route            = [
                  + {
                      + cidr_block                = "0.0.0.0/0"
                      + egress_only_gateway_id    = ""
                      + gateway_id                = ""
                      + instance_id               = ""
                      + ipv6_cidr_block           = ""
                      + local_gateway_id          = ""
                      + nat_gateway_id            = (known after apply)
                      + network_interface_id      = ""
                      + transit_gateway_id        = ""
                      + vpc_endpoint_id           = ""
                      + vpc_peering_connection_id = ""
                    },
                ]
              + tags             = {
                  + "Name" = "rt-an2-mytf-prod-nat-pub-a"
                }
              + vpc_id           = (known after apply)
            }
        }
      + subnet          = {
          + private-a = {
              + arn                             = (known after apply)
              + assign_ipv6_address_on_creation = false
              + availability_zone               = "ap-northeast-2a"
              + availability_zone_id            = (known after apply)
              + cidr_block                      = "10.0.128.0/24"
              + id                              = (known after apply)
              + ipv6_cidr_block                 = null
              + ipv6_cidr_block_association_id  = (known after apply)
              + map_public_ip_on_launch         = false
              + outpost_arn                     = null
              + owner_id                        = (known after apply)
              + tags                            = {
                  + "Name" = "igw-an2-mytf-prod-pri-a"
                }
              + timeouts                        = null
              + vpc_id                          = (known after apply)
            }
          + private-c = {
              + arn                             = (known after apply)
              + assign_ipv6_address_on_creation = false
              + availability_zone               = "ap-northeast-2c"
              + availability_zone_id            = (known after apply)
              + cidr_block                      = "10.0.192.0/24"
              + id                              = (known after apply)
              + ipv6_cidr_block                 = null
              + ipv6_cidr_block_association_id  = (known after apply)
              + map_public_ip_on_launch         = false
              + outpost_arn                     = null
              + owner_id                        = (known after apply)
              + tags                            = {
                  + "Name" = "igw-an2-mytf-prod-pri-c"
                }
              + timeouts                        = null
              + vpc_id                          = (known after apply)
            }
          + public-a  = {
              + arn                             = (known after apply)
              + assign_ipv6_address_on_creation = false
              + availability_zone               = "ap-northeast-2a"
              + availability_zone_id            = (known after apply)
              + cidr_block                      = "10.0.0.0/24"
              + id                              = (known after apply)
              + ipv6_cidr_block                 = null
              + ipv6_cidr_block_association_id  = (known after apply)
              + map_public_ip_on_launch         = false
              + outpost_arn                     = null
              + owner_id                        = (known after apply)
              + tags                            = {
                  + "Name" = "igw-an2-mytf-prod-pub-a"
                }
              + timeouts                        = null
              + vpc_id                          = (known after apply)
            }
          + public-c  = {
              + arn                             = (known after apply)
              + assign_ipv6_address_on_creation = false
              + availability_zone               = "ap-northeast-2c"
              + availability_zone_id            = (known after apply)
              + cidr_block                      = "10.0.64.0/24"
              + id                              = (known after apply)
              + ipv6_cidr_block                 = null
              + ipv6_cidr_block_association_id  = (known after apply)
              + map_public_ip_on_launch         = false
              + outpost_arn                     = null
              + owner_id                        = (known after apply)
              + tags                            = {
                  + "Name" = "igw-an2-mytf-prod-pub-c"
                }
              + timeouts                        = null
              + vpc_id                          = (known after apply)
            }
        }
    }
  + vpc    = {
      + igw_id = (known after apply)
      + vpc_id = (known after apply)
    }

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

# 8. Terraform apply

```bash
$ terraform apply

...생략

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

module.create_vpc.aws_vpc.this[0]: Creating...
module.create_subnet.aws_eip.this["public-a"]: Creating...
module.create_subnet.aws_eip.this["public-a"]: Creation complete after 0s [id=eipalloc-00ddce6511d86136e]
module.create_vpc.aws_vpc.this[0]: Creation complete after 1s [id=vpc-016ddf9fced28b736]
module.create_vpc.aws_internet_gateway.this[0]: Creating...
module.create_subnet.aws_subnet.this["public-a"]: Creating...
module.create_subnet.aws_subnet.this["public-c"]: Creating...
module.create_subnet.aws_subnet.this["private-a"]: Creating...
module.create_subnet.aws_subnet.this["private-c"]: Creating...
module.create_vpc.aws_internet_gateway.this[0]: Creation complete after 1s [id=igw-0a57302a804f7a422]
module.create_subnet.aws_subnet.this["public-a"]: Creation complete after 1s [id=subnet-065ddf01b38c995e5]
module.create_subnet.aws_route_table.route_table_igw: Creating...
module.create_subnet.aws_subnet.this["private-c"]: Creation complete after 1s [id=subnet-0bfda31ed59442b68]
module.create_subnet.aws_subnet.this["private-a"]: Creation complete after 1s [id=subnet-03e1048078557e0d7]
module.create_subnet.aws_subnet.this["public-c"]: Creation complete after 1s [id=subnet-036f4dfebe7dcbd95]
module.create_subnet.aws_nat_gateway.this["public-a"]: Creating...
module.create_subnet.aws_route_table.route_table_igw: Creation complete after 0s [id=rtb-0d9641642fdbc2c2d]
module.create_subnet.aws_route_table_association.route_table_igw["public-a"]: Creating...
module.create_subnet.aws_route_table_association.route_table_igw["public-c"]: Creating...
module.create_subnet.aws_route_table_association.route_table_igw["public-c"]: Creation complete after 1s [id=rtbassoc-0a65d91ca886f9f72]
module.create_subnet.aws_route_table_association.route_table_igw["public-a"]: Creation complete after 1s [id=rtbassoc-01a53db01032e4bcb]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [10s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [20s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [30s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [40s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [50s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [1m0s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [1m10s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [1m20s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [1m30s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still creating... [1m40s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Creation complete after 1m45s [id=nat-038ec0137cd40638e]
module.create_subnet.aws_route_table.route_table_nat["public-a"]: Creating...
module.create_subnet.aws_route_table.route_table_nat["public-a"]: Creation complete after 1s [id=rtb-0113461240df2358b]
module.create_subnet.aws_route_table_association.route_table_nat["private-a"]: Creating...
module.create_subnet.aws_route_table_association.route_table_nat["private-c"]: Creating...
module.create_subnet.aws_route_table_association.route_table_nat["private-a"]: Creation complete after 1s [id=rtbassoc-0982bee996eaaa4c8]
module.create_subnet.aws_route_table_association.route_table_nat["private-c"]: Creation complete after 1s [id=rtbassoc-0319c7e6f27445732]

Apply complete! Resources: 14 added, 0 changed, 0 destroyed.

Outputs:

subnet = {
  "route_table_igw" = "rtb-0d9641642fdbc2c2d"
  "route_table_nat" = {
    "public-a" = {
      "id" = "rtb-0113461240df2358b"
      "owner_id" = "703507686712"
      "propagating_vgws" = toset([])
      "route" = toset([
        {
          "cidr_block" = "0.0.0.0/0"
          "egress_only_gateway_id" = ""
          "gateway_id" = ""
          "instance_id" = ""
          "ipv6_cidr_block" = ""
          "local_gateway_id" = ""
          "nat_gateway_id" = "nat-038ec0137cd40638e"
          "network_interface_id" = ""
          "transit_gateway_id" = ""
          "vpc_endpoint_id" = ""
          "vpc_peering_connection_id" = ""
        },
      ])
      "tags" = tomap({
        "Name" = "rt-an2-mytf-prod-nat-pub-a"
      })
      "vpc_id" = "vpc-016ddf9fced28b736"
    }
  }
  "subnet" = {
    "private-a" = {
      "arn" = "arn:aws:ec2:ap-northeast-2:703507686712:subnet/subnet-03e1048078557e0d7"
      "assign_ipv6_address_on_creation" = false
      "availability_zone" = "ap-northeast-2a"
      "availability_zone_id" = "apne2-az1"
      "cidr_block" = "10.0.128.0/24"
      "id" = "subnet-03e1048078557e0d7"
      "ipv6_cidr_block" = ""
      "ipv6_cidr_block_association_id" = ""
      "map_public_ip_on_launch" = false
      "outpost_arn" = ""
      "owner_id" = "703507686712"
      "tags" = tomap({
        "Name" = "igw-an2-mytf-prod-pri-a"
      })
      "timeouts" = null /* object */
      "vpc_id" = "vpc-016ddf9fced28b736"
    }
    "private-c" = {
      "arn" = "arn:aws:ec2:ap-northeast-2:703507686712:subnet/subnet-0bfda31ed59442b68"
      "assign_ipv6_address_on_creation" = false
      "availability_zone" = "ap-northeast-2c"
      "availability_zone_id" = "apne2-az3"
      "cidr_block" = "10.0.192.0/24"
      "id" = "subnet-0bfda31ed59442b68"
      "ipv6_cidr_block" = ""
      "ipv6_cidr_block_association_id" = ""
      "map_public_ip_on_launch" = false
      "outpost_arn" = ""
      "owner_id" = "703507686712"
      "tags" = tomap({
        "Name" = "igw-an2-mytf-prod-pri-c"
      })
      "timeouts" = null /* object */
      "vpc_id" = "vpc-016ddf9fced28b736"
    }
    "public-a" = {
      "arn" = "arn:aws:ec2:ap-northeast-2:703507686712:subnet/subnet-065ddf01b38c995e5"
      "assign_ipv6_address_on_creation" = false
      "availability_zone" = "ap-northeast-2a"
      "availability_zone_id" = "apne2-az1"
      "cidr_block" = "10.0.0.0/24"
      "id" = "subnet-065ddf01b38c995e5"
      "ipv6_cidr_block" = ""
      "ipv6_cidr_block_association_id" = ""
      "map_public_ip_on_launch" = false
      "outpost_arn" = ""
      "owner_id" = "703507686712"
      "tags" = tomap({
        "Name" = "igw-an2-mytf-prod-pub-a"
      })
      "timeouts" = null /* object */
      "vpc_id" = "vpc-016ddf9fced28b736"
    }
    "public-c" = {
      "arn" = "arn:aws:ec2:ap-northeast-2:703507686712:subnet/subnet-036f4dfebe7dcbd95"
      "assign_ipv6_address_on_creation" = false
      "availability_zone" = "ap-northeast-2c"
      "availability_zone_id" = "apne2-az3"
      "cidr_block" = "10.0.64.0/24"
      "id" = "subnet-036f4dfebe7dcbd95"
      "ipv6_cidr_block" = ""
      "ipv6_cidr_block_association_id" = ""
      "map_public_ip_on_launch" = false
      "outpost_arn" = ""
      "owner_id" = "703507686712"
      "tags" = tomap({
        "Name" = "igw-an2-mytf-prod-pub-c"
      })
      "timeouts" = null /* object */
      "vpc_id" = "vpc-016ddf9fced28b736"
    }
  }
}
vpc = {
  "igw_id" = "igw-0a57302a804f7a422"
  "vpc_id" = "vpc-016ddf9fced28b736"
}
(venv)
```

# 9. Terraform destroy

```bash
# --auto-aaprove를 사용하면 yes 입력을 요구하는 프롬프트가 발생하지 않습니다.
$ terraform destroy --auto-approve

module.create_subnet.aws_route_table_association.route_table_igw["public-c"]: Destroying... [id=rtbassoc-0a65d91ca886f9f72]
module.create_subnet.aws_route_table_association.route_table_nat["private-c"]: Destroying... [id=rtbassoc-0319c7e6f27445732]
module.create_subnet.aws_route_table_association.route_table_nat["private-a"]: Destroying... [id=rtbassoc-0982bee996eaaa4c8]
module.create_subnet.aws_route_table_association.route_table_igw["public-a"]: Destroying... [id=rtbassoc-01a53db01032e4bcb]
module.create_subnet.aws_route_table_association.route_table_igw["public-a"]: Destruction complete after 1s
module.create_subnet.aws_route_table_association.route_table_igw["public-c"]: Destruction complete after 1s
module.create_subnet.aws_route_table_association.route_table_nat["private-c"]: Destruction complete after 1s
module.create_subnet.aws_route_table_association.route_table_nat["private-a"]: Destruction complete after 1s
module.create_subnet.aws_route_table.route_table_igw: Destroying... [id=rtb-0d9641642fdbc2c2d]
module.create_subnet.aws_route_table.route_table_nat["public-a"]: Destroying... [id=rtb-0113461240df2358b]
module.create_subnet.aws_route_table.route_table_nat["public-a"]: Destruction complete after 0s
module.create_subnet.aws_route_table.route_table_igw: Destruction complete after 0s
module.create_vpc.aws_internet_gateway.this[0]: Destroying... [id=igw-0a57302a804f7a422]
module.create_subnet.aws_nat_gateway.this["public-a"]: Destroying... [id=nat-038ec0137cd40638e]
module.create_vpc.aws_internet_gateway.this[0]: Still destroying... [id=igw-0a57302a804f7a422, 10s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still destroying... [id=nat-038ec0137cd40638e, 10s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still destroying... [id=nat-038ec0137cd40638e, 20s elapsed]
module.create_vpc.aws_internet_gateway.this[0]: Still destroying... [id=igw-0a57302a804f7a422, 20s elapsed]
module.create_vpc.aws_internet_gateway.this[0]: Still destroying... [id=igw-0a57302a804f7a422, 30s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still destroying... [id=nat-038ec0137cd40638e, 30s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Still destroying... [id=nat-038ec0137cd40638e, 40s elapsed]
module.create_vpc.aws_internet_gateway.this[0]: Still destroying... [id=igw-0a57302a804f7a422, 40s elapsed]
module.create_vpc.aws_internet_gateway.this[0]: Destruction complete after 46s
module.create_subnet.aws_nat_gateway.this["public-a"]: Still destroying... [id=nat-038ec0137cd40638e, 50s elapsed]
module.create_subnet.aws_nat_gateway.this["public-a"]: Destruction complete after 52s
module.create_subnet.aws_eip.this["public-a"]: Destroying... [id=eipalloc-00ddce6511d86136e]
module.create_subnet.aws_subnet.this["private-a"]: Destroying... [id=subnet-03e1048078557e0d7]
module.create_subnet.aws_subnet.this["private-c"]: Destroying... [id=subnet-0bfda31ed59442b68]
module.create_subnet.aws_subnet.this["public-a"]: Destroying... [id=subnet-065ddf01b38c995e5]
module.create_subnet.aws_subnet.this["public-c"]: Destroying... [id=subnet-036f4dfebe7dcbd95]
module.create_subnet.aws_subnet.this["public-c"]: Destruction complete after 0s
module.create_subnet.aws_subnet.this["public-a"]: Destruction complete after 0s
module.create_subnet.aws_subnet.this["private-a"]: Destruction complete after 0s
module.create_subnet.aws_subnet.this["private-c"]: Destruction complete after 0s
module.create_vpc.aws_vpc.this[0]: Destroying... [id=vpc-016ddf9fced28b736]
module.create_subnet.aws_eip.this["public-a"]: Destruction complete after 0s
module.create_vpc.aws_vpc.this[0]: Destruction complete after 1s

Destroy complete! Resources: 14 destroyed.
```