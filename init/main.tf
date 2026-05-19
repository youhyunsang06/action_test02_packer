
# version 명시하기
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
        source  = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}

# 1. provider 설정
provider "aws" {
    region = "ap-northeast-2" # 서울 리전
}

# s3 버킷 및  IAM 설정 (새로 추가할 로직)
resource "random_id" "bucket_suffix" {
    # 4 byte 크기의 렌덤한 문자열을 얻어내기 위한 설정
    byte_length = 4
}

# s3 버킷 정의하기
resource "aws_s3_bucket" "tfstate_bucket" {
    # s3 버킷의 이름은 전세계에서 유일해야 한다
    # 문자열을 너무 간단히 부여하면 에러가 나면서 만들어지지 않는다
    # 4 byte 크기의 random 한 16진수를 뒤에 붙여서 겹치지 않는 이름이 나오게 한다.
    bucket = "tfstate-bucket-${random_id.bucket_suffix.hex}"    #.hex는 16진수라는 의미
}

output "bucket_id" {
    value = aws_s3_bucket.tfstate_bucket.id
}

resource "aws_dynamodb_table" "terraform_lock" {
    name = "terraform-lock-test02" # 테이블명 마음대로 지을수 있다  
    billing_mode = "PAY_PER_REQUEST" # 비용 지불 방식 (요청 갯수당 과금하겠다 비용미미함)
    hash_key = "LockID"  # 카테고리명 마음대로 지을수 있다. (RDBMS 의 PK 과 유사)

    # 속성을 이용해서  
    attribute{
        name = "LockID" # 카테고리의 
        type = "S" # 데이터 type 을 설정한다  S 는 문자열  N 은 숫자 
    }
    tags = {
        Name = "Terraform State Lock Table"
    }
}