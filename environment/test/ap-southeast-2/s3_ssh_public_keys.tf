variable "ssh_public_key_names" {
  default = "kha,kien,william"
}

resource "aws_s3_bucket" "ssh_public_keys" {
  region = "${data.aws_region.current.name}"
  bucket = "${var.bastion_bucket_name}"
  acl    = "private"
  force_destroy = true
}

resource "aws_s3_bucket_object" "ssh_public_keys" {
  bucket = "${aws_s3_bucket.ssh_public_keys.bucket}"
  key    = "${element(split(",", var.ssh_public_key_names), count.index)}.pub"

  # Make sure that you put files into correct location and name them accordingly (`public_keys/{keyname}.pub`)
  content = "${file("public_keys/${element(split(",", var.ssh_public_key_names), count.index)}.pub")}"
  count   = "${length(split(",", var.ssh_public_key_names))}"

  depends_on = ["aws_s3_bucket.ssh_public_keys"]
}

data "aws_region" "current" {
  current = true
}
