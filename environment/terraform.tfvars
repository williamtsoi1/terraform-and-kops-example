# Configure Terragrunt to automatically store tfstate files in an S3 bucket
terragrunt = {
  remote_state {
    backend = "s3"
    config {
      encrypt = true
      bucket = "stratasnap-terraform-remote-state"
      key = "${path_relative_to_include()}/terraform.tfstate"
      region = "ap-southeast-2"
    }
  }
}
