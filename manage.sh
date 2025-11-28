#!/bin/bash

# CHEAQI Docker Management Script
# This script provides easy management commands for the CHEAQI containerization

set -e

PROJECT_NAME="cheaqi-spatial-workbench"
COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to build the container
build() {
    print_header "Building CHEAQI Container"
    check_docker
    
    print_status "Building Docker image..."
    docker-compose build --no-cache
    
    print_status "Build completed successfully!"
}

# Function to start services
start() {
    print_header "Starting CHEAQI Services"
    check_docker
    
    print_status "Starting Jupyter notebook service..."
    docker-compose up -d cheaqi-notebook
    
    sleep 5
    
    print_status "CHEAQI Jupyter Lab is starting up..."
    print_status "Access the notebook at: http://localhost:8888"
    print_status "Use 'docker logs cheaqi-spatial-workbench' to see startup logs"
}

# Function to start with file server
start_with_fileserver() {
    print_header "Starting CHEAQI Services with File Server"
    check_docker
    
    print_status "Starting all services..."
    docker-compose --profile fileserver up -d
    
    sleep 5
    
    print_status "Services started successfully!"
    print_status "Jupyter Lab: http://localhost:8888"
    print_status "File Server: http://localhost:8080"
}

# Function to start batch processor
start_batch() {
    print_header "Starting CHEAQI Batch Processor"
    check_docker
    
    print_status "Starting batch processing service..."
    docker-compose --profile batch up -d cheaqi-processor
    
    print_status "Batch processor is ready!"
    print_status "Run commands with: docker exec -it cheaqi-batch-processor bash"
}

# Function to stop services
stop() {
    print_header "Stopping CHEAQI Services"
    
    print_status "Stopping all services..."
    docker-compose down
    
    print_status "All services stopped."
}

# Function to show logs
logs() {
    print_header "CHEAQI Service Logs"
    
    if [ -z "$2" ]; then
        docker-compose logs -f
    else
        docker-compose logs -f "$2"
    fi
}

# Function to show status
status() {
    print_header "CHEAQI Service Status"
    
    docker-compose ps
}

# Function to clean up
clean() {
    print_header "Cleaning CHEAQI Environment"
    
    print_warning "This will remove all containers and images. Continue? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_status "Stopping services..."
        docker-compose down
        
        print_status "Removing images..."
        docker-compose down --rmi all --volumes --remove-orphans
        
        print_status "Cleanup completed!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Function to enter container shell
shell() {
    print_header "Entering CHEAQI Container Shell"
    
    if docker ps | grep -q "cheaqi-spatial-workbench"; then
        docker exec -it cheaqi-spatial-workbench bash -c "source activate cheaqi && bash"
    else
        print_error "CHEAQI container is not running. Start it first with: $0 start"
        exit 1
    fi
}

# Function to run a processing workflow
process() {
    print_header "Running CHEAQI Processing Workflow"
    
    if [ -z "$2" ]; then
        print_error "Please specify a CSV file: $0 process <csv_file>"
        exit 1
    fi
    
    CSV_FILE="$2"
    
    if [ ! -f "./data/$CSV_FILE" ]; then
        print_error "CSV file not found in ./data/$CSV_FILE"
        exit 1
    fi
    
    print_status "Processing $CSV_FILE..."
    docker exec -it cheaqi-spatial-workbench bash -c "
        source activate cheaqi &&
        cd /app/scripts &&
        python batch_process.py --input /app/data/$CSV_FILE --output /app/outputs
    "
}

# Function to show help
help() {
    echo "CHEAQI Docker Management Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  build              Build the Docker image"
    echo "  start              Start the Jupyter notebook service"
    echo "  start-full         Start with file server"
    echo "  start-batch        Start batch processor"
    echo "  stop               Stop all services"
    echo "  restart            Restart all services"
    echo "  status             Show service status"
    echo "  logs [service]     Show logs (optionally for specific service)"
    echo "  shell              Enter container shell"
    echo "  process <csv>      Process CSV file with batch workflow"
    echo "  clean              Clean up containers and images"
    echo "  help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build                    # Build the container"
    echo "  $0 start                    # Start Jupyter Lab"
    echo "  $0 logs cheaqi-notebook     # Show notebook logs"
    echo "  $0 process data.csv         # Process data.csv file"
}

# Main script logic
case "$1" in
    build)
        build
        ;;
    start)
        start
        ;;
    start-full)
        start_with_fileserver
        ;;
    start-batch)
        start_batch
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status
        ;;
    logs)
        logs "$@"
        ;;
    shell)
        shell
        ;;
    process)
        process "$@"
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        help
        exit 1
        ;;
esac