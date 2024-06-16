
#creating local name for my resources
locals {
  name = "row"
}

#creating pvc 
resource "aws_vpc" "vpc" {
  cidr_block       = var.cidr
  instance_tenancy = "default"

  tags = {
    Name = "${local.name}-vpc"
  }
}
//creating pub_subnets
resource "aws_subnet" "sub1" {
  availability_zone = var.az1
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidr2

  tags = {
    Name = "${local.name}-sub1"
  }
}

#creating internet_gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.name}-gw"
  }
}

#creating pub_route_table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.allcidr
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "${local.name}-rt"
  }
}

#creating route_table_association 
resource "aws_route_table_association" "rt1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

# RSA key of size 4096 bits
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

//creating private key
resource "local_file" "key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "rowprom.pem"
  file_permission = 400
}

//creating public key
resource "aws_key_pair" "key" {
  key_name   = "rowpromkey"
  public_key = tls_private_key.key.public_key_openssh
}

//creating seccurity group for prometheus and grafana
resource "aws_security_group" "prom_graf_sg" {
  name        = "prom_graf_sg"
  description = "allow inbound traffic"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  ingress {
    description = "prometheus_job_port"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  ingress {
    description = "node_exporter_port"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  ingress {
    description = "grafana_port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allcidr]
  }

  tags = {
    Name = "${local.name}-prod_graf_sg"
  }
}

//creating seccurity group for maven
resource "aws_security_group" "target-sg" {
  name        = "target_server sg"
  description = "allow inbound traffic"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  ingress {
    description = "node_exporter_port"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  ingress {
    description = "httpd_port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allcidr]
  }

  tags = {
    Name = "${local.name}-target-sg"
  }
}

//creating ec2 for docker vault
resource "aws_instance" "prom_graf" {
  ami                         = var.ubuntu //prom_graf ubuntu ami
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.key.id
  vpc_security_group_ids      = [aws_security_group.prom_graf_sg.id]
  subnet_id                   = aws_subnet.sub1.id
  associate_public_ip_address = true
  user_data                   = templatefile("./userdata1.sh", {
    nginx_webserver_ip        = aws_instance.docker.public_ip
  })
  depends_on = [aws_instance.docker]
  tags = {
    Name = "${local.name}-prom_graf"
  }
}

//creating ec2 for docker vault
resource "aws_instance" "docker" {
  ami                         = var.ubuntu //ec2 ubuntu ami
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.key.id
  vpc_security_group_ids      = [aws_security_group.target-sg.id]
  subnet_id                   = aws_subnet.sub1.id
  associate_public_ip_address = true
  user_data                   = file("./userdata2.sh")
  tags = {
    Name = "${local.name}-docker"
  }
}




