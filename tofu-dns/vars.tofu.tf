variable "state_encryption_passphrase" {
  description = "Passphrase used to encrypt the Terraform state file"
  type        = string
  sensitive   = true
}
