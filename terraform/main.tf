terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Create a VPC for network isolation
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "node-postgres-vpc"
  }
}

# 2. Create Public Subnets (used by the ECS Fargate tasks)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "node-postgres-public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "node-postgres-public-2"
  }
}

# 2b. Create Private Subnets (used by the RDS database only)
resource "aws_subnet" "private_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.101.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"

  tags = {
    Name = "node-postgres-private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.102.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"

  tags = {
    Name = "node-postgres-private-2"
  }
}

# 3. Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "node-postgres-igw"
  }
}

# 4. Create Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "node-postgres-rt"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Private route table: no route to the Internet Gateway, local VPC traffic only
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "node-postgres-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# 5. Create ECS Cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "node-postgres-cluster"
}

# 6. Create Security Group for Database
#    Only the ECS tasks' security group may connect on 5432.
resource "aws_security_group" "db_sg" {
  name   = "node-postgres-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from the ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  tags = {
    Name = "node-postgres-db-sg"
  }
}

# 7. Create RDS Subnet Group (private subnets)
#    create_before_destroy: the new group is created first, the database is
#    moved onto it, and only then is the old group deleted.
resource "aws_db_subnet_group" "db_subnet" {
  name       = "node-postgres-db-subnet-private"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "node-postgres-db-subnet-private"
  }
}

# 7b. Generate the database password (no longer hard-coded)
resource "random_password" "db" {
  length  = 24
  special = false # keeps the password safe to embed in a connection URL
}

# 8. Create RDS PostgreSQL Database
resource "aws_db_instance" "postgres" {
  identifier             = "node-postgres-db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "visits_db"
  username               = "postgresuser"
  password               = random_password.db.result
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  apply_immediately      = true
}

# 8b. Store the full connection string in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_url" {
  name                    = "node-postgres-app/database-url"
  recovery_window_in_days = 0 # lets `terraform destroy` delete it immediately
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql://postgresuser:${random_password.db.result}@${aws_db_instance.postgres.endpoint}/visits_db"
}

# 9. Create Amazon ECR Repository to store Docker images
resource "aws_ecr_repository" "app_repo" {
  name                 = "node-postgres-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Output the ECR Repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

# 9b. CloudWatch log group so we can see container output and errors
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/node-postgres-app"
  retention_in_days = 7
}

# 10. IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "node-postgres-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 10b. Allow the execution role to read ONLY the database secret
resource "aws_iam_role_policy" "read_db_secret" {
  name = "node-postgres-read-db-secret"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.db_url.arn
      }
    ]
  })
}

# 11. Security Group for ECS Task
resource "aws_security_group" "ecs_sg" {
  name   = "node-postgres-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 3000
    to_port     = 3000
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

# 12. ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "node-postgres-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "node-postgres-app"
      image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      environment = [
        {
          name  = "PORT"
          value = "3000"
        }
      ]
      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.db_url.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  depends_on = [aws_iam_role_policy.read_db_secret]
}

# 13. ECS Service (Runs the container on Fargate)
resource "aws_ecs_service" "app_service" {
  name            = "node-postgres-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}