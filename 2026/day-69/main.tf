provider "aws" {
  region = "ap-south-1"
}

resource "aws_key_pair" "key" {
  key_name   = "ansible-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_security_group" "allow_ssh" {
  name = "allow_ssh"

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

resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = { Name = "web-server" }
}

resource "aws_instance" "app" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = { Name = "app-server" }
}

resource "aws_instance" "db" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = { Name = "db-server" }
}

output "ips" {
  value = {
    web = aws_instance.web.public_ip
    app = aws_instance.app.public_ip
    db  = aws_instance.db.public_ip
  }
}
