# Terraform 및 Provider 버전 설정
terraform {
  required_version = ">= 1.14.0" # 테라폼 실행기 자체의 버전을 제약합니다.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # 최신 기능 사용을 위해 5.0 이상 권장 (현재 6.0은 아직 대중적이지 않을 수 있음)
    }
  }
   backend "s3" {
    bucket = "tfstate-bucket-7a8a8149"
    key = "test02/terraform.tfstate" #/test01/하위에 만들어 지도록
    region = "ap-northeast-2"
    dynamodb_table = "terraform-lock-test02" # 미리 준비된 dynamodb 테이블의 이름을 명시하면 lock 상태가 자동으로 관리된다.
    encrypt = true #tfstate에는 민감한 정보가 있을수 있기 때문에 암호화
    }
}

# AWS 프로바이더 설정: 모든 리소스는 서울 리전에 생성됩니다.
provider "aws" {
  region = "ap-northeast-2"
}