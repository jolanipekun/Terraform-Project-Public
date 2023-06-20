

variable "db_password" {
    type = string
    description = "RDS root user password"
    sensitive   = true
   
}