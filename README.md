# Node.js and PostgreSQL Containerized Application

A full-stack web application featuring a Node.js and Express backend, a PostgreSQL database, containerized using Docker Compose, and provisioned on AWS using Terraform.

## Project Architecture

* **Frontend:** HTML and JavaScript interface served via Express.
* **Backend:** Node.js and Express API handling database transactions.
* **Database:** PostgreSQL storing application visit records.
* **Containerization:** Docker and Docker Compose for local multi-container orchestration.
* **Infrastructure as Code:** Terraform for provisioning AWS resources.

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