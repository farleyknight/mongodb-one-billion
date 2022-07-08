provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "The region in which to create and manage resources"
  default     = "us-east-1"
}

terraform {
  required_version = ">= 0.12.0"
}

resource "aws_security_group" "main" {
  egress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 0
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "-1"
      security_groups  = []
      self             = false
      to_port          = 0
    }
  ]
  ingress = [
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 22
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 22
    },
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 80
    },
    {
      cidr_blocks      = ["0.0.0.0/0", ]
      description      = ""
      from_port        = 27017
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 27017
    }
  ]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical (Ubuntu)
}

resource "aws_instance" "ec2_mongodb-config" {
  # NOTE: This is the AMI that is built in Packer for MongoDB
  # It's from the mongodb-aws-ubuntu.pkr.hcl file
  ami                    = "ami-0fad438c832b80058" 
  instance_type          = "t2.micro"
  key_name               = "mongodb-key-pair-one-billion"
  vpc_security_group_ids = [aws_security_group.main.id]

  connection {
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("mongodb-key-pair-one-billion.pem")
    timeout     = "3m"
  }

  provisioner "file" {
    source      = "mongod.config.conf"
    destination = "/home/ubuntu/mongod.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/ubuntu/mongod.conf /etc/mongod.conf",
      "sudo systemctl start mongod",
      "sleep 10", # Wait for mongod to be responsive
      "sudo mongo --host localhost --eval \"printjson(rs.initiate())\"", # https://www.mongodb.com/docs/manual/reference/method/rs.initiate/
      "sudo mongo --host localhost --eval \"printjson(rs.status())\""
    ]
  }
}

resource "aws_instance" "ec2_mongodb-shard1" {
  # NOTE: This is the AMI that is built in Packer for MongoDB
  # It's from the mongodb-aws-ubuntu.pkr.hcl file
  ami                    = "ami-0fad438c832b80058" 
  instance_type          = "t2.micro"
  key_name               = "mongodb-key-pair-one-billion"
  vpc_security_group_ids = [aws_security_group.main.id]

  connection {
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("mongodb-key-pair-one-billion.pem")
    timeout     = "3m"
  }

  provisioner "file" {
    source      = "mongod.shard1.conf"
    destination = "/home/ubuntu/mongod.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/ubuntu/mongod.conf /etc/mongod.conf",
      "sudo systemctl start mongod",
      "sleep 10", # Wait for mongod to be responsive
      "sudo mongo --host localhost --eval \"printjson(rs.initiate())\"", # https://www.mongodb.com/docs/manual/reference/method/rs.initiate/
      "sudo mongo --host localhost --eval \"printjson(rs.status())\""
    ]
  }
}

resource "aws_instance" "ec2_mongodb-shard2" {
  # NOTE: This is the AMI that is built in Packer for MongoDB
  # It's from the mongodb-aws-ubuntu.pkr.hcl file
  ami                    = "ami-0fad438c832b80058" 
  instance_type          = "t2.micro"
  key_name               = "mongodb-key-pair-one-billion"
  vpc_security_group_ids = [aws_security_group.main.id]

  connection {
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("mongodb-key-pair-one-billion.pem")
    timeout     = "3m"
  }

  provisioner "file" {
    source      = "mongod.shard2.conf"
    destination = "/home/ubuntu/mongod.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/ubuntu/mongod.conf /etc/mongod.conf",
      "sudo systemctl start mongod",
      "sleep 10", # Wait for mongod to be responsive
      "sudo mongo --host localhost --eval \"printjson(rs.initiate())\"", # https://www.mongodb.com/docs/manual/reference/method/rs.initiate/
      "sudo mongo --host localhost --eval \"printjson(rs.status())\""
    ]
  }
}

locals {
  shard1_private_dns = replace(aws_instance.ec2_mongodb-shard1.private_dns, ".ec2.internal", "")
  shard2_private_dns = replace(aws_instance.ec2_mongodb-shard2.private_dns, ".ec2.internal", "")
}

resource "aws_instance" "ec2_mongodb-router" {
  # NOTE: This is the AMI that is built in Packer for MongoDB
  # It's from the mongodb-aws-ubuntu.pkr.hcl file
  ami                    = "ami-0fad438c832b80058" 
  instance_type          = "t2.micro"
  key_name               = "mongodb-key-pair-one-billion"
  vpc_security_group_ids = [aws_security_group.main.id]

  connection {
    host        = self.public_ip
    user        = "ubuntu"
    private_key = file("mongodb-key-pair-one-billion.pem")
    timeout     = "3m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mongos --bind_ip_all --syslog --fork --configdb config/${aws_instance.ec2_mongodb-config.public_dns}:27017",
      "sleep 10",
      "sudo mongo --eval \"printjson(rs.status())\"",
      "sleep 10",
      "sudo mongo --eval \"printjson(sh.addShard('shard1/${local.shard1_private_dns}:27017'))\"",
      "sudo mongo --eval \"printjson(sh.addShard('shard2/${local.shard2_private_dns}:27017'))\"",
      "sudo mongo --eval \"printjson(rs.status())\""
    ]
  }

  depends_on = [
    aws_instance.ec2_mongodb-config,
    aws_instance.ec2_mongodb-shard1,
    aws_instance.ec2_mongodb-shard2
  ]
}

// MongoDB config

output "mongodb-config_public_dns" {
  value = aws_instance.ec2_mongodb-config.public_dns
}

output "mongodb-config_ip_address" {
  value = aws_instance.ec2_mongodb-config.public_ip
}

// MongoDB shard1

output "mongodb-shard1_public_dns" {
  value = aws_instance.ec2_mongodb-shard1.public_dns
}

output "mongodb-shard1_ip_address" {
  value = aws_instance.ec2_mongodb-shard1.public_ip
}

// MongoDB shard2

output "mongodb-shard2_public_dns" {
  value = aws_instance.ec2_mongodb-shard2.public_dns
}

output "mongodb-shard2_ip_address" {
  value = aws_instance.ec2_mongodb-shard2.public_ip
}

// MongoDB router

output "mongodb-router_public_dns" {
  value = aws_instance.ec2_mongodb-router.public_dns
}

output "mongodb-router_ip_address" {
  value = aws_instance.ec2_mongodb-router.public_ip
}