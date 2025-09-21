#!/bin/bash

# Local Docker Test Script
# This script helps you test your Flask app locally with Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🐳 Local Docker Testing for Content Summary Bot${NC}"

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker is not running${NC}"
        exit 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not available${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Function to setup environment
setup_environment() {
    echo -e "${BLUE}📝 Setting up environment...${NC}"
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}⚠️  .env file not found. Creating from template...${NC}"
        cat > .env << EOF
# OpenAI Configuration (Required - Replace with your actual keys)
OPENAI_API_KEY=your_openai_api_key_here
OPENAI_ORG_ID=your_openai_org_id_here

# Flask Configuration
FLASK_SECRET=local_development_secret_key_123456789
FLASK_APP=app1.py
FLASK_ENV=development
EOF
        echo -e "${RED}🔑 IMPORTANT: Please edit .env file with your actual OpenAI API keys!${NC}"
        echo -e "${YELLOW}📝 File location: $(pwd)/.env${NC}"
    else
        echo -e "${GREEN}✅ .env file found${NC}"
    fi
    
    # Check if database file exists
    if [ ! -f "companies.db" ]; then
        echo -e "${YELLOW}📊 Creating empty database file...${NC}"
        touch companies.db
    fi
}

# Function to build and run
build_and_run() {
    echo -e "${BLUE}🔨 Building Docker image...${NC}"
    
    # Build the image
    if docker-compose build; then
        echo -e "${GREEN}✅ Docker image built successfully${NC}"
    else
        echo -e "${RED}❌ Docker build failed${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}🚀 Starting the application...${NC}"
    
    # Run with docker-compose
    if docker-compose up -d; then
        echo -e "${GREEN}✅ Application started successfully${NC}"
        
        # Wait a moment for the container to fully start
        sleep 5
        
        # Check if the container is running
        if docker-compose ps | grep -q "Up"; then
            echo -e "${GREEN}🌐 Application is running at: http://localhost:5000${NC}"
            echo -e "${BLUE}📊 Container status:${NC}"
            docker-compose ps
        else
            echo -e "${RED}❌ Container failed to start${NC}"
            echo -e "${YELLOW}📋 Showing logs:${NC}"
            docker-compose logs
        fi
    else
        echo -e "${RED}❌ Failed to start application${NC}"
        exit 1
    fi
}

# Function to show useful commands
show_commands() {
    echo -e "${BLUE}📚 Useful Commands:${NC}"
    echo -e "${YELLOW}View logs:${NC} docker-compose logs -f"
    echo -e "${YELLOW}Stop application:${NC} docker-compose down"
    echo -e "${YELLOW}Restart application:${NC} docker-compose restart"
    echo -e "${YELLOW}Rebuild and restart:${NC} docker-compose up --build -d"
    echo -e "${YELLOW}Access container shell:${NC} docker-compose exec content-summary-bot bash"
    echo -e "${YELLOW}View database:${NC} docker-compose exec content-summary-bot sqlite3 companies.db"
}

# Main function
main() {
    echo -e "${GREEN}Starting local Docker testing...${NC}"
    
    check_prerequisites
    setup_environment
    
    echo -e "${BLUE}What would you like to do?${NC}"
    echo "1. Build and run (fresh start)"
    echo "2. Stop application"
    echo "3. View logs"
    echo "4. Restart application"
    echo "5. Clean up (remove containers and images)"
    
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            build_and_run
            show_commands
            ;;
        2)
            echo -e "${YELLOW}🛑 Stopping application...${NC}"
            docker-compose down
            echo -e "${GREEN}✅ Application stopped${NC}"
            ;;
        3)
            echo -e "${BLUE}📋 Showing logs...${NC}"
            docker-compose logs -f
            ;;
        4)
            echo -e "${YELLOW}🔄 Restarting application...${NC}"
            docker-compose restart
            echo -e "${GREEN}✅ Application restarted${NC}"
            ;;
        5)
            echo -e "${YELLOW}🧹 Cleaning up...${NC}"
            docker-compose down
            docker rmi content-summary-bot_content-summary-bot 2>/dev/null || true
            docker system prune -f
            echo -e "${GREEN}✅ Cleanup completed${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"