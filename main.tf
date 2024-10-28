terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider este
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "vpc_base" {
  cidr_block = "10.0.0.0/16"


	# el nombre de mi vpc
	tags = {
	   Name = "vpc_base"
	 }
 }

 # Crear una subred privada
resource "aws_subnet" "subnet_private" {
  vpc_id     = aws_vpc.vpc_base.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "subnet_private_base"
  }
}
 
# Crear una subred pública
resource "aws_subnet" "subnet_public" {
  vpc_id            = aws_vpc.vpc_base.id
  cidr_block        = "10.0.100.0/24"
  
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_public_base"
  }
}

#crear una ip elastic
resource "aws_eip" "vpc-base-eip" {
  public_ipv4_pool = "amazon"

  tags = {
    Name = "vpc-base-eip"
  }
}

resource "aws_internet_gateway" "vpc-base-igw" {
  vpc_id = aws_vpc.vpc_base.id

  tags = {
    Name = "vpc_base_igw"
  }
}


#crear un Nat gateway
resource "aws_nat_gateway" "vpc-base-nat-gateway" {
  allocation_id = aws_eip.vpc-base-eip.id
  subnet_id     = aws_subnet.subnet_public.id
  depends_on = [ aws_eip.vpc-base-eip ]

  tags = {
    Name = "vpc-base-nat-gateway"
  }
}

# Crear un route table
resource "aws_route_table" "vpc-base-rt" {
  vpc_id = aws_vpc.vpc_base.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc-base-igw.id
  }

  tags = {
    Name = "vpc_base_rt"
  }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.vpc-base-rt.id
}

#crear una instancia
resource "aws_security_group" "permitir_ssh_http" {
  name        = "permitir_ssh"
  description = "Permitir SSH y HTTP"
  vpc_id      = aws_vpc.vpc_base.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "permitir_ssh_http"
  }
}


resource "aws_instance" "nginx-server" {
  ami           = "ami-0866a3c8686eaeeba"
  instance_type = "t2.micro"

network_interface {
  network_interface_id = aws_network_interface.nginx-interface.id
  
  device_index         = 0
}

# instalar nginx con un script 
  user_data = <<-EOF
              #!/bin/bash
              sudo apt install nginx -y
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF

  key_name = aws_key_pair.nginx-server-key.key_name


  tags = {
    Name = "web_instance_base"
  }

  
}


#crear una interfaz para instancia
resource "aws_network_interface" "nginx-interface" {
  subnet_id   = aws_subnet.subnet_public.id
  private_ips = ["10.0.100.10"]
  security_groups = [aws_security_group.permitir_ssh_http.id]

  tags = {
    Name = "network_interface"
  }
}

#crear una llave publica a ver si funciona
resource "aws_key_pair" "nginx-server-key" {
  key_name   = "nginx-server-key"
  public_key = file("nginx-server.key.pub")
}








