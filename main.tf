variable "subnets" {
  default = ["eu-west-1a","eu-west-1b","eu-west-1c"]
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "oni" {
  cidr_block = "192.168.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.oni.id}"
}

resource "aws_route" "internet_access" {
  route_table_id = "${aws_vpc.oni.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.default.id}"
}

resource "aws_security_group" "default" {
  vpc_id      = "${aws_vpc.oni.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "default" {
  count = "${length(var.subnets)}"
  availability_zone = "${element(var.subnets, count.index)}"
  cidr_block = "192.168.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id = "${aws_vpc.oni.id}"
}

data "aws_ami" "ubuntu-1604" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_iam_role" "hephaestus" {
  name = "hephaestus"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      tag-key = "tag-value"
  }
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.hephaestus.name}"
}

resource "aws_iam_role_policy" "omnipotent" {
  name = "omnipotent"
  role = "${aws_iam_role.hephaestus.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_instance" "ssh_host" {
  ami           = "${data.aws_ami.ubuntu-1604.id}"
  iam_instance_profile = "${aws_iam_instance_profile.test_profile.name}"
  instance_type = "t3.nano"
  key_name = "hephaestus-pair"
  subnet_id              = "${element(aws_subnet.default.*.id,0)}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  user_data              = "sudo apt-get update;sudo apt-get install git"
}

output "ssh_host" {
  value = "${aws_instance.ssh_host.public_ip}"
}