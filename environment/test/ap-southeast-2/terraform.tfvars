environment_name = "test1"
region = "ap-southeast-2"
vpc_cidr = "10.70.0.0/16"
availability_zones = ["ap-southeast-2a","ap-southeast-2b","ap-southeast-2c"]
public_subnets = ["10.70.0.0/22", "10.70.4.0/22", "10.70.8.0/22"]
private_subnets = ["10.70.32.0/19", "10.70.64.0/19", "10.70.96.0/19"]
number_of_cassandra_seeds = "3"
cassandra_instance_type = "m3.medium"
cassandra_seed_ips = ["10.70.32.128", "10.70.64.128", "10.70.96.128"]
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnW0IJtw0ggHVbOJA2F58jilN0FjlbZcmDvzGQRYDOEicEOV1U0RMNmDcEouoTnMLQ7SNUWy08Q8w2hqPPLAU8sUQgYrCe4DRRN/Iu1WM2l0wV1UQ2MBrVBdpJPNo3v7v8lE315lU8zI/rdUGa1c9gxXMELjIqcb+4YyCHs3IHHG1sNVqbWoEnq1frRGQ6SuRcJLfF4JppGB8/zwXD2KfGWCPfu6shgmS0eVe1u7qVlEBkU3drSGz0GoMD5ldeWGDaCs0wM15yRuLkpc6EKyT2eLD36EQ+D03vn5Dr7EGmOyvNbLHKxN8BEjM4Rz+3qBmZwGq5jvwKTorXhQ7zZbgT williamtsoi@Williams-MBP"
bastion_bucket_name = "devop5-terragrunt-strata-snap-ssh-keys"
terragrunt = {
  include {
    path = "${find_in_parent_folders()}"
  }
}
