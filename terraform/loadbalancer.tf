# test09_alb/loadbalancer.tf

# Route 53 도메인 장부 정보 읽어오기
data "aws_route53_zone" "selected" {
  name = "${var.domain_name}."
  private_zone = false
}

# 미리 만들어서 준비된 인증서 가져오기 
data "aws_acm_certificate" "issued_cert" {
  domain = "*.${var.domain_name}"
  statuses = ["ISSUED"]
  most_recent = true
}

# 테스트용으로 인증서의 arn 출력해 보기
output "certificate_arn" {
  value = data.aws_acm_certificate.issued_cert.arn
}

# =========================================================
#  HTTPS 리스너: 인증서를 달고 443 포트를 개방합니다.
# =========================================================
resource "aws_lb_listener" "https" {
  # 아래에서 만든 ALB 의 arn 
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # route53.tf 에서 만든 인증서의 arn (직접 발급받아서 사용할꺼면 아래의 코드)
  # certificate_arn   = aws_acm_certificate_validation.cert.certificate_arn

  # 여기에서는 route53.tf 를 실행하지 않고 미리 발급받은 인증서의 arn 을 사용한다
  certificate_arn = data.aws_acm_certificate.issued_cert.arn

  # 리스너가 받은 요청을 처리하는 기본 동작 설정
  default_action {
    type             = "forward"
    # 전달할 목적지의 고유 주소(ARN)
    # 위에서 정의한 Target Group(바구니)으로 손님을 보냅니다.
    # 결국 "ALB 입구 -> 리스너 -> 대상 그룹 -> 실제 EC2" 순으로 연결되는 핵심 고리입니다.
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 80 port 로 들어오는 요청을 443 port 로 리다일렉트 시킨다 
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"
  # 443 port 로 리다일렉트 이동시키는 설정
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# =========================================================
# 도메인 레코드 연결: Route 53에 ALB 주소를 등록합니다.
# =========================================================
# www.도메인 연결
resource "aws_route53_record" "www" {
  # 어느 호스팅 영역(도메인 관리소)에 기록할지 ID 지정
  # data.aws_route53_zone.selected 는 route53.tf 에 있음
  zone_id = data.aws_route53_zone.selected.zone_id
  # 실제 사용할 도메인 이름 (예: www.cloud-study.in)
  name    = "www.${var.domain_name}"
  # 레코드 타입: A 레코드 (IPv4 주소 연결)
  # 하지만 아래 alias 설정을 쓰면 단순 IP가 아닌 AWS 리소스로 직접 연결됩니다.
  type    = "A"
  #  별칭(Alias) 설정: AWS 리소스를 도메인에 직접 매핑
  alias {
    # 연결할 대상: 위에서 만든 ALB의 실제 DNS 주소
    name                   = aws_lb.web_alb.dns_name
    # ALB가 속한 지역의 고유 ID (Route 53이 내부적으로 경로를 찾을 때 사용)
    zone_id                = aws_lb.web_alb.zone_id
    # 대상의 상태 확인: ALB가 죽어있으면 DNS 응답을 하지 않도록 설정 (고가용성)
    evaluate_target_health = true
  }
}

# 루트(root) 도메인 연결
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true
  }
}


# 1. ALB 전용 보안 그룹 (Security Group)
# 외부 손님이 들어올 수 있게 80(HTTP)과 443(HTTPS)을 열어줍니다.
resource "aws_security_group" "alb_sg" {
  name        = "lecture-alb-sg"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.main.id #


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# 2. ALB 본체 (Load Balancer L7)
resource "aws_lb" "web_alb" {
    name = "lecture-alb"
    internal = false # 외부 노출용
    load_balancer_type = "application" # 로드벨러서 종류
    security_groups = [aws_security_group.alb_sg.id] # 위에서 정의한 보안그룹 적용
    # 고가용성 을 위해 최소 2개의 public subnet 을 제공해야 한다.
    subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    # tag
    tags = {
      Name = "lecture-alb"
    }
}


# 3. ALB 가 받은 요청을 최종적으로 전달할 대상그룹
resource "aws_lb_target_group" "web_tg" {
    name = "lecture-tg"
    # 대상 ec2 에서 돌아가는 web 서버의 port 번호(변경가능)
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id
    # 헬스 체크: 로드밸런서가 각 EC2에게 "너 살아있니?"라고 주기적으로 물어보는 설정입니다.
    # 아래의 설정은 health_check 를 생략했을때 적용되는 default 옵션입니다.
    health_check {
        enabled             = true           # 헬스 체크 기능을 활성화합니다.
        path                = "/"            # EC2의 어느 경로로 접속해서 확인할지 결정합니다. (기본 루트 페이지)
        port                = "traffic-port" # 위에서 설정한 80포트를 그대로 사용하여 확인합니다.
        protocol            = "HTTP"         # 상태 확인 시 사용할 통신 규약입니다.
       
        # [판단 기준]
        healthy_threshold   = 5  # 연속 5번 성공하면 "이 친구 건강하네!"라고 판단 (서비스 투입)
        unhealthy_threshold = 2  # 연속 2번 실패하면 "이 친구 아프네?"라고 판단 (서비스 제외)
       
        # [시간 설정]
        timeout             = 5  # 응답을 기다리는 최대 시간(초). 이 시간 넘기면 실패로 간주합니다.
        interval            = 30 # 다음 확인까지 기다리는 주기(초). 너무 짧으면 서버에 부담을 줍니다.
    }    
}






output "alb_dns_name" {
  description = "여기로 접속하세요!"
  value       = aws_lb.web_alb.dns_name
}
