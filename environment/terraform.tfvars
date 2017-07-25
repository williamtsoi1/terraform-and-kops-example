# Configure Terragrunt to automatically store tfstate files in an S3 bucket
terragrunt = {
  remote_state {
    backend = "s3"
    config {
      encrypt = true
      bucket = "terragrunt-strata-snap-remote-state"
      key = "${path_relative_to_include()}/terraform.tfstate"
      region = "ap-southeast-2"
    }
  }
}
