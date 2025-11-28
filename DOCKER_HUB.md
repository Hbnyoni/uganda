# Docker Hub Integration for CHEAQI Uganda Workflow

## Automated Docker Builds

This repository is configured for automated Docker image builds on Docker Hub.

### Docker Images Available:
- **Main Image**: `yourusername/cheaqi-uganda:latest`
- **Web Interface**: `yourusername/cheaqi-uganda:web`
- **Processor**: `yourusername/cheaqi-uganda:processor`

### Quick Start with Docker Hub Images:
```bash
# Pull and run the latest image
docker pull yourusername/cheaqi-uganda:latest
docker run -d -p 8888:8888 --name uganda-analysis yourusername/cheaqi-uganda:latest

# Or use Docker Compose with remote images
docker-compose -f docker-compose.hub.yml up -d
```

### Build Status:
[![Docker Build Status](https://img.shields.io/docker/build/yourusername/cheaqi-uganda)](https://hub.docker.com/r/yourusername/cheaqi-uganda/)
[![Docker Pulls](https://img.shields.io/docker/pulls/yourusername/cheaqi-uganda)](https://hub.docker.com/r/yourusername/cheaqi-uganda/)

### Tags Available:
- `latest` - Most recent stable build
- `v1.0` - Tagged release version
- `dev` - Development branch builds

### Auto-Build Configuration:
- **Source**: GitHub repository
- **Trigger**: Push to main branch
- **Context**: Root directory
- **Dockerfile**: `Dockerfile`