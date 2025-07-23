resource "aws_security_group" "nfs_sg" {
  name   = "nfs-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 111
    to_port     = 111
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 20048
    to_port     = 20048
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 32765
    to_port     = 32769
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

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

resource "aws_spot_instance_request" "cheap_worker" {
 
  ami           = var.ami
  instance_type = var.instance_type
  spot_type     = "persistent"
  subnet_id     = var.subnet_ids[0]
  wait_for_fulfillment = true
  key_name = var.aws_key_name
  vpc_security_group_ids = [aws_security_group.nfs_sg.id]

  instance_interruption_behavior = "stop" 
  user_data = file("${path.module}/script/main.yaml")
    root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true 
  
    }
tags = {
    Name = "nfs-spot-instance" 
  }
  

}
resource "aws_route53_zone" "internal" {
  name = "internal"
  vpc {
    vpc_id = var.vpc_id
  }
}
resource "aws_route53_record" "nfs" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "nfs.internal"
  type    = "A"
  ttl     = 300
  records = [aws_spot_instance_request.cheap_worker.private_ip]
}
