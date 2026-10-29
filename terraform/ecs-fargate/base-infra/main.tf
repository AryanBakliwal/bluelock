variable "join_token" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

provider "aws" {
  region = "us-east-1"
}

# --- Networking ---
resource "aws_vpc" "bluelock_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "bluelock-vpc" }
}

resource "aws_subnet" "bluelock_subnet" {
  vpc_id                  = aws_vpc.bluelock_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "bluelock-subnet" }
}

resource "aws_internet_gateway" "bluelock_igw" {
  vpc_id = aws_vpc.bluelock_vpc.id
  tags = { Name = "bluelock-igw" }
}

resource "aws_route_table" "bluelock_rt" {
  vpc_id = aws_vpc.bluelock_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bluelock_igw.id
  }
  tags = { Name = "bluelock-rt" }
}

resource "aws_route_table_association" "bluelock_rta" {
  subnet_id      = aws_subnet.bluelock_subnet.id
  route_table_id = aws_route_table.bluelock_rt.id
}

resource "aws_security_group" "bluelock_sg" {
  name        = "bluelock-sg"
  vpc_id      = aws_vpc.bluelock_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "bluelock-sg" }
}

# --- EC2 Node ---
data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "cp_node" {
  ami                    = data.aws_ami.ubuntu_24_04.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.bluelock_subnet.id
  vpc_security_group_ids = [aws_security_group.bluelock_sg.id]
  key_name               = var.ssh_key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data_replace_on_change = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              curl -fsSL https://get.docker.com -o get-docker.sh
              sh get-docker.sh
              systemctl enable --now docker
              usermod -aG docker ubuntu

              # Wait until Docker daemon is fully responsive before proceeding
              while ! systemctl is-active --quiet docker; do sleep 2; done

              curl -sfL https://knoxctl-cli.s3.us-east-2.amazonaws.com/install.sh | sudo sh -s -- -b /usr/local/bin

              sudo -i -u ubuntu /usr/local/bin/knoxctl onboard vm cp-node \
                --version v0.12.5 \
                --join-token=${var.join_token} \
                --spire-host=spire.demo.accuknox.com \
                --pps-host=pps.demo.accuknox.com \
                --knox-gateway=knox-gw.demo.accuknox.com:3000
                --sumengine-viz="process,network,file" \
              EOF
  tags = { Name = "cp-node" }
}

# --- IAM & Logging ---
resource "aws_cloudwatch_log_group" "ecs_armored_container" {
  name              = "/ecs/armored-container"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRolePolicy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- ECS Cluster & Task Definition ---
resource "aws_ecs_cluster" "bluelock_test" {
  name = "bluelock-test"
}

resource "aws_ecs_cluster_capacity_providers" "bluelock_test_fargate" {
  cluster_name       = aws_ecs_cluster.bluelock_test.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_ecs_task_definition" "worker_node" {
  family                   = "worker-node"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "kubearmor-dir"
  }

  volume {
    name = "opt-storage"
  }

  container_definitions = templatefile("${path.module}/task-definition.json", {
    cp_node_ip     = aws_instance.cp_node.public_ip
    log_group_name = aws_cloudwatch_log_group.ecs_armored_container.name
  })
}