# Node.js and PostgreSQL Containerized Application

A robust, production-ready full-stack web application featuring a Node.js and Express backend coupled with a PostgreSQL database. This project demonstrates modern cloud-native engineering practices, containerization via Docker Compose, and infrastructure provisioning and deployment on AWS using Terraform, Amazon ECR, and Amazon ECS Fargate.

## Project Architecture

This application is engineered using a modular, cloud-agnostic architecture designed for seamless scalability and portability:

- **Frontend:** A responsive HTML, CSS, and JavaScript user interface served directly via the Express web server, providing an interactive visit counter and status dashboard.
- **Backend:** A Node.js and Express API server responsible for handling client requests, executing secure database queries, and managing connection pooling.
- **Database:** A managed PostgreSQL database instance storing application visit records, featuring automated database table initialization on startup to prevent race conditions.
- **Containerization:** Docker and Docker Compose configured to handle multi-container local orchestration, ensuring complete environment parity between development and production.
- **Infrastructure as Code (IaC):** Terraform modules provisioning a custom AWS networking stack (VPC, public subnets, Internet Gateway), an RDS PostgreSQL database instance, and an ECS cluster.
- **Registry & Orchestration:** Amazon Elastic Container Registry (ECR) for storing versioned Docker images, deployed via serverless containers on Amazon ECS Fargate.

## Project Structure

```text
node-postgres-app/
├── public/
│   └── index.html
├── src/
│   └── server.js
├── terraform/
│   └── main.tf
├── .env.example
├── .gitignore
├── Dockerfile
├── docker-compose.yml
└── package.json
```

## Environment Variables Reference

| Variable | Description | Default / Example Value |
| --- | --- | --- |
| `DATABASE_URL` | Full connection URI string for PostgreSQL | `postgresql://postgresuser:postgrespassword@postgres_db:5432/visits_db` |
| `PORT` | Network port number on which the Express server listens | `3000` |

## Local Development Setup

Follow these instructions to set up, build, and run the complete multi-container application locally on your machine for development and testing.

### Prerequisites

- **Docker & Docker Compose:** Ensure Docker Engine and Docker Compose are installed and running on your operating system.
- **Node.js:** Installed locally if you wish to run direct debugging sessions outside containers.

### Running Locally with Docker Compose

1. **Clone the repository**

   Open your terminal and clone the project repository from GitHub, then navigate into the project root directory:

   ```bash
   git clone https://github.com/njambiiankaranja/node-postgres-app.git
   cd node-postgres-app
   ```

2. **Configure environment variables**

   Create a local `.env` file in the root directory modeled after the provided `.env.example` file:

   ```env
   DATABASE_URL=postgresql://postgresuser:postgrespassword@postgres_db:5432/visits_db
   PORT=3000
   ```

3. **Build and start the containers**

   Use Docker Compose to build the application image and spin up both the Node.js web container and the PostgreSQL database container in an isolated network:

   ```bash
   docker compose up --build
   ```

4. **Access the application**

   Open your preferred web browser and navigate to the local server endpoint:

   ```text
   http://localhost:3000
   ```

## AWS Infrastructure Provisioning and Deployment

Follow these sequential steps to provision cloud infrastructure using Terraform, package and push your container image to AWS ECR, and launch the service on AWS ECS Fargate.

### 1. Provision Infrastructure and ECR Repository via Terraform

Navigate into the `terraform/` directory, initialize the Terraform working directory to download provider plugins, and apply the infrastructure configuration:

```bash
cd terraform
terraform init
terraform apply
```

Review the execution plan and type `yes` to confirm. Make sure to copy the `ecr_repository_url` output displayed in your terminal once the apply completes successfully.

### 2. Build, Tag, and Push Docker Image to AWS ECR

Return to the root project directory, authenticate your local Docker client with your private AWS Elastic Container Registry, build the production image, tag it with your ECR repository URL, and push it up to AWS:

```bash
cd ..
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ECR_REPOSITORY_URL

docker build -t node-postgres-app .
docker tag node-postgres-app:latest YOUR_ECR_REPOSITORY_URL:latest
docker push YOUR_ECR_REPOSITORY_URL:latest
```

> **Note:** Replace `YOUR_ECR_REPOSITORY_URL` with the actual ECR repository URI string returned from your Terraform output.

### 3. Deploy Application to ECS Fargate

Return to the `terraform/` directory and run `terraform apply` once more. This provisions the ECS Task Definition, execution roles, security groups, and the ECS Service needed to pull your image from ECR and run your container live on Fargate:

```bash
cd terraform
terraform apply
```

### 4. Accessing the Deployed Application in AWS

1. Log in to the AWS Management Console and search for **ECS**.
2. Click on your cluster name (`node-postgres-cluster`) and select the **Tasks** tab.
3. Click on the running task ID to open its details.
4. Locate the **Public IP** address assigned to the task under its networking configuration.
5. Open your browser and access your live cloud-deployed web application at:

   ```text
   http://YOUR_TASK_PUBLIC_IP:3000
   ```

## Cleanup and Resource Destruction

To completely tear down all provisioned AWS resources (VPC, subnets, RDS database, ECS cluster, and ECR repository) and prevent any ongoing cloud charges, run the following destruction command inside the `terraform/` directory:

```bash
cd terraform
terraform destroy
```