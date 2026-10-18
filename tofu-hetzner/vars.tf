variable "state_encryption_passphrase" {
  description = "Passphrase used to encrypt the state and plan files"
  type        = string
  sensitive   = true
}
