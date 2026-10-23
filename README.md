# Node.js and PostgreSQL Containerized Application

A full-stack web application featuring a Node.js and Express backend, a PostgreSQL database, containerized using Docker Compose, and provisioned and deployed on AWS using Terraform, ECR, and ECS Fargate.

## Project Architecture

* **Frontend:** HTML and JavaScript interface served via Express.
* **Backend:** Node.js and Express API handling database queries and connection pooling.
* **Database:** PostgreSQL storing application visit records with automated table initialization on startup.
* **Containerization:** Docker and Docker Compose for local multi-container orchestration.
* **Infrastructure as Code:** Terraform for provisioning AWS resources including VPC, Subnets, Internet Gateway, RDS PostgreSQL, and ECS Fargate.
* **Registry:** Amazon Elastic Container Registry (ECR) for hosting Docker images.

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
