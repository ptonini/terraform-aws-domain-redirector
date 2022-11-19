module "certificate" {
  source = "github.com/ptonini/terraform-aws-acm-certificate?ref=v1"
  domain_name = var.domains[0]
  subject_alternative_names = [for d in var.domains : d if index(var.domains, d) != 0]
  route53_zone = var.route53_zone
  providers = {
    aws.current = aws.current
    aws.dns = aws.dns
  }
}

module "security_group" {
  source = "github.com/ptonini/terraform-aws-security-group?ref=v1"
  vpc = var.vpc
  builtin_ingress_rules = [
    "http",
    "https"
  ]
  egress_rules = {
    1 = {
      from_port = 0
      protocol = -1
      cidr_blocks = [for s in var.subnets : s["cidr_block"]]
      ipv6_cidr_blocks = []
    }
  }
  providers = {
    aws = aws.current
  }
}

module "load_balancer" {
  source = "github.com/ptonini/terraform-aws-ec2-loadbalancer?ref=v1"
  subnet_ids = [for s in var.subnets : s["id"]]
  log_bucket_name = var.log_bucket_name
  security_group_ids = [
    module.security_group.this.id
  ]
  listeners = {
    1 = {
      port = var.port
      protocol = var.protocol
      certificate = module.certificate.this
      actions = var.actions
      rules = var.rules
    }
  }
  builtin_listeners = ["http_to_https"]
  region = var.region
  account_id = var.account_id
  providers = {
    aws = aws.current
  }
}

module "dns_record" {
  source = "github.com/ptonini/terraform-aws-route53-record?ref=v1"
  for_each = toset(var.domains)
  name = each.value
  route53_zone = var.route53_zone
  alias = {
    name = module.load_balancer.this.dns_name
    zone_id = module.load_balancer.this.zone_id
  }
  providers = {
    aws = aws.dns
  }
}