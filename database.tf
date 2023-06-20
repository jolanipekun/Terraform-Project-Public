resource "aws_db_instance" "LUIT_db" {
    allocated_storage = 5
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t2.micro"
    username = "rancher"
    password = "var.db_password"
    parameter_group_name = "default.mysql5.7"
    skip_final_snapshot = true
}