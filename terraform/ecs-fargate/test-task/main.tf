provider "aws" {
  region = "us-east-1"
}

# Fetch the subnet by its tag
data "aws_subnet" "bluelock_subnet" {
  filter {
    name   = "tag:Name"
    values = ["bluelock-subnet"]
  }
}

# Fetch the security group by its tag
data "aws_security_group" "bluelock_sg" {
  filter {
    name   = "tag:Name"
    values = ["bluelock-sg"]
  }
}

# Fetch the cluster by name
data "aws_ecs_cluster" "bluelock_test" {
  cluster_name = "bluelock-test"
}

# Fetch the latest active revision of the task definition
data "aws_ecs_task_definition" "worker_node" {
  task_definition = "worker-node"
}

# Deploy the task using the fetched data
resource "aws_ecs_service" "worker_test_service" {
  name            = "worker-test-service"
  cluster         = data.aws_ecs_cluster.bluelock_test.id
  task_definition = data.aws_ecs_task_definition.worker_node.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [data.aws_subnet.bluelock_subnet.id]
    security_groups  = [data.aws_security_group.bluelock_sg.id]
    assign_public_ip = true
  }
}