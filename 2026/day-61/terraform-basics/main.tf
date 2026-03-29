
provider "aws" {
  region = "us-west-2"

}

resource "aws_s3_bucket" "Mayanksbucket" {
  bucket = "terraweek-mayankizisi-ays"
}

resource "aws_instance" "server" {
  ami           = "ami-0d76b909de1a0595d"
  instance_type = "t3.micro"


  tags = {
    Name = "TerraWeek-Day1" 

  }
}
