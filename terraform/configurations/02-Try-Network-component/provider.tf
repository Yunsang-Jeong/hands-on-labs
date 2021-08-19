#
# 파일명 : provider.tf
#

# Terraform에서 지원하는 provider 중, AWS를 사용하겠다는 의미입니다.
provider "aws" {
  region  = "ap-northeast-2"
  profile = "default"
  # 프로파일을 사용하지 않는 경우 다음과 같이 access_key, secret_key를 기입해도 됩니다.
  # access_key = "" 
  # secret_key = ""
}

# Terraform에서 State 파일과 Lock에 대한 내용입니다.
# terraform {
#   backend "s3" {
#     region = "ap-northeast-2"
#     bucket = "S3_버킷_이름"
#     key    = "terraform.tfstate"
#     dynamodb_table  = "DynamoDB_테이블_이름"
#   }
# }