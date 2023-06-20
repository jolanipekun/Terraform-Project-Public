# configured aws provider with proper credentials
provider "aws" {
  region  = "us-east-1"
  profile = "jolanipekun"
}


# store the terraform state file in s3
terraform {
  backend "s3" {
    bucket  = "test-bucket-405"
    key     = "build/terraform.tfstate"
    region  = "us-east-1"
    profile = "jolanipekun"
  }
}


# create a custom vpc 
resource "aws_vpc" "custom" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Custom Vpc"
  }
}


# The variables define a list of strings that essentially hold the CIDR ranges for each subnet. 
# The two variables represent different lists of CIDR ranges for public and private subnets.
variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
 
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# Creating custom subnets
resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.custom.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.custom.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

# variable to store the list of availability zones as below.
variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}


resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.custom.id
 
 tags = {
   Name = "Project VPC IG"
 }
}

# A Second route table associated with the same VPC in the resource block
resource "aws_route_table" "second_rt" {
 vpc_id = aws_vpc.custom.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "2nd Route Table"
 }
}

# Associating Public Subnets to the Second Route Table
resource "aws_route_table_association" "public_subnet_asso" {
 count = length(var.public_subnet_cidrs)
 subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
 route_table_id = aws_route_table.second_rt.id
}

#####################################################################################################
# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80 and 22"
  vpc_id      = aws_vpc.custom.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2 security group"
  }
}



# use data source to get a registered amazon linux 2 ami
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}




# launch the ec2 instance and install website
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnets[0].id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "aws_key"
  user_data              = file("install_techmax.sh")
  associate_public_ip_address = true

  tags = {
    Name = "techmax server"
  }
}



resource "aws_key_pair" "devkey" {
  key_name   = "aws_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDHjnzN0Sm1ttGaVJZm6vZ97NmlhzIfVREjiVr5Pu3lYCv1wu/ZGpATCHnj/NXzAlXoLsGoX9aRvmTUsWwS5gRDokoU7T/h/6g4JPrgkitE5+EZSNW23ognclM85EdWJ+A1SDQK7uo1xqE5SJ9vBnyqkaEiHgKu35d1E95u34cRnpQ4UwNDcAhln/Z7R/xESljNsXPt5z7Wh8LiimX/jpozvVufPzP6YfdwCtevhIRvI/fg6t7GqoPXo/h+wF13p+R6saPRNBpmaa9iaqaOwHF2Z1ElCkNNz0QXjfJ+tbxDy/Tw7lTHns50nIAuMFYs0bG1uEvBrLPBxtUL4QVaZ9jv vix/jolanipekun@50N47S3"

}


# print the url of the server
output "ec2_public_ipv4_url" {
  value = join("", ["http://", aws_instance.ec2_instance.public_ip])
}

