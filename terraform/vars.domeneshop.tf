variable "domeneshop" {
  description = "Domeneshop e-mail configuration"
  sensitive   = false
  default = {
    mx = "mx.domeneshop.no"

    spf-empty = "\"v=spf1 -all\""
    spf-ds    = "\"v=spf1 include:_spf.domeneshop.no -all\""

    ds-rua        = "dmarc@domeneshop.no"
    dmarc         = "\"v=DMARC1; p=reject; adkim=s; aspf=s; fo=1; sp=reject;\""
    dmarc-ruf     = "\"v=DMARC1; p=reject; adkim=s; aspf=s; fo=1; sp=reject; ruf=%s;\""
    dmarc-rua     = "\"v=DMARC1; p=reject; adkim=s; aspf=s; fo=1; sp=reject; rua=%s;\""
    dmarc-ruf-rua = "\"v=DMARC1; p=reject; adkim=s; aspf=s; fo=1; sp=reject; ruf=%s; rua=%s;\""
  }
}
