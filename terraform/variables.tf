variable "region" { default = "ap-northeast-2" }
variable "instance_type" { default = "t3.micro" }

# autoscaling 그룹에서 원하는 ec2의 갯수
variable "desired_capacity" { default = 2 }

# 최소 ec2의 갯수
variable "min_size" { default = 1 }

# 최대 ec2의 갯수
variable "max_size" { default = 5 }

# 첫번째 가용영역
variable "avail_zone_1" { default = "ap-northeast-2a" }

# 두번째 가용영역
variable "avail_zone_2" { default = "ap-northeast-2c" }

# ec2 의 갯수
variable "ec2_count" { default = 3 }

variable "domain_name" {
    default = "delipure.shop"
}