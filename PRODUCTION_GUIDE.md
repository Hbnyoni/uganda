# 🚀 CHEAQI Spatial Interpolation System - Production Guide

## 📋 System Overview

The CHEAQI Spatial Interpolation System is a containerized web application that provides:
- **Advanced CSV data analysis** with comprehensive variable exploration
- **Spatial interpolation** using Kriging and IDW methods
- **Batch processing** with Nextflow workflow automation
- **Interactive web interface** for data visualization and control

## 🏗️ Architecture Components

### Core Technologies
- **Docker & Docker Compose**: Container orchestration
- **Flask 2.x**: Web framework with RESTful APIs
- **Nextflow 25.10.0**: Workflow automation engine
- **Python 3.11**: Runtime with scientific computing stack
- **Mambaforge**: Package and environment management

### Spatial Analysis Stack
- **PyKrige**: Geostatistical kriging interpolation
- **GDAL 3.7+**: Geospatial data abstraction library
- **GeoPandas**: Geographic data manipulation
- **Rasterio**: Raster data I/O and processing
- **SciPy**: Scientific computing and optimization

## 🎯 Key Features

### 1. Advanced Variable Selection
- **Individual Variable Control**: Select each variable with granular control
- **Smart Filtering**: Filter by type, quality, statistics, and categories
- **Data Quality Assessment**: Automatic outlier detection and missing value analysis
- **Statistical Preview**: Min/max values, distributions, and variance analysis

### 2. Spatial Interpolation Methods
- **Kriging**: Geostatistical optimal interpolation with uncertainty quantification
- **IDW**: Inverse Distance Weighting for deterministic interpolation
- **Cross-Validation**: Automatic model validation and performance metrics

### 3. Batch Processing
- **Nextflow Workflows**: Automated batch processing of multiple datasets
- **Parallel Execution**: Concurrent processing of multiple interpolation tasks
- **Resource Management**: Configurable CPU and memory allocation
- **Progress Monitoring**: Real-time workflow status and logging

## 🚦 Production Deployment

### Prerequisites
- Docker Desktop 4.0+ or Docker Engine 20.0+
- Docker Compose 2.0+
- 8GB+ RAM recommended
- 10GB+ disk space for data and outputs

### Quick Start
```bash
# 1. Clone/download the system
git clone <repository> # or extract from archive

# 2. Navigate to project directory
cd cheaqi-docker

# 3. Start the system
docker-compose up -d --build

# 4. Access the web interface
# Open browser to: http://localhost:8080
```

### Environment Configuration
```yaml
# docker-compose.yml - Production settings
services:
  cheaqi-web:
    ports:
      - "8080:5000"  # Change port as needed
    volumes:
      - ./data:/app/data
      - ./outputs:/app/outputs
    environment:
      - FLASK_ENV=production
      - PYTHONUNBUFFERED=1
```

### Data Directory Structure
```
cheaqi-docker/
├── data/                    # Input CSV files
│   ├── Gambia_Daily.csv
│   ├── Kenya_Daily.csv
│   ├── Mozambique_Daily.csv
│   ├── South Africa.csv
│   └── Uganda_Daily.csv
├── outputs/                 # Generated results
│   ├── interpolated_maps/
│   ├── validation_reports/
│   └── workflow_logs/
└── notebooks/              # Analysis notebooks
    └── cheaqi_interactive_containerization.ipynb
```

## 🔧 Configuration Files

### Nextflow Configuration (`nextflow.config`)
```groovy
process {
    executor = 'local'
    cpus = 2
    memory = '4 GB'
    
    withName: 'SPATIAL_INTERPOLATION' {
        cpus = 4
        memory = '8 GB'
    }
}

conda {
    enabled = true
    cacheDir = '/app/.conda-cache'
}
```

### Application Configuration (`scripts/config.json`)
```json
{
    "interpolation": {
        "default_method": "kriging",
        "kriging_model": "spherical",
        "idw_power": 2.0,
        "grid_resolution": 0.01
    },
    "validation": {
        "cv_folds": 5,
        "test_split": 0.2,
        "random_seed": 42
    }
}
```

## 📊 Usage Workflows

### Single Dataset Analysis
1. **Upload CSV**: Place CSV file in `data/` directory
2. **Select Variables**: Use Variable Explorer for detailed selection
3. **Configure Method**: Choose Kriging or IDW interpolation
4. **Run Analysis**: Execute single interpolation task
5. **Download Results**: Access maps and reports in `outputs/`

### Batch Processing
1. **Prepare Datasets**: Multiple CSV files in `data/` directory
2. **Launch Workflow**: Use Nextflow batch processing
3. **Monitor Progress**: Check workflow status in web interface
4. **Collect Results**: Batch outputs in organized directory structure

## 🔍 API Endpoints

### Core APIs
- `GET /api/files` - List available CSV files
- `POST /api/process/<filename>` - Single file processing
- `GET /api/get_all_variables/<filename>` - Variable analysis
- `POST /api/run_nextflow` - Batch workflow execution

### Variable Selection APIs
- `GET /variable_explorer/<filename>` - Advanced variable interface
- `GET /variables/<filename>` - Simple variable selection
- `POST /api/interpolate` - Execute interpolation with selected variables

## 🛡️ Security & Performance

### Security Considerations
- **File Validation**: CSV format and size validation
- **Input Sanitization**: All user inputs are sanitized
- **Resource Limits**: Memory and CPU usage constraints
- **Network Isolation**: Container network security

### Performance Optimization
- **Conda Caching**: Environment caching for faster startups
- **Parallel Processing**: Multi-core interpolation execution
- **Memory Management**: Efficient handling of large datasets
- **Result Caching**: Intermediate result storage

## 🔧 Troubleshooting

### Common Issues
1. **Docker Build Failures**: Check Docker daemon and memory allocation
2. **Port Conflicts**: Modify port mapping in docker-compose.yml
3. **Memory Issues**: Increase Docker memory limits for large datasets
4. **Nextflow Errors**: Check Java installation and environment variables

### Logs and Monitoring
```bash
# View application logs
docker-compose logs cheaqi-web

# Monitor resource usage
docker stats

# Check Nextflow execution
docker exec -it cheaqi-spatial-web nextflow log
```

## 📈 Scaling for Production

### Horizontal Scaling
- Deploy multiple container instances
- Use load balancer (nginx, HAProxy)
- Shared storage for data and outputs

### Resource Scaling
```yaml
# docker-compose.yml - Resource limits
deploy:
  resources:
    limits:
      cpus: '4.0'
      memory: 8G
    reservations:
      cpus: '2.0'
      memory: 4G
```

## 🎯 Final System Capabilities

✅ **Complete Variable Control**: Select and analyze individual variables  
✅ **Advanced Filtering**: Multi-criteria variable filtering system  
✅ **Batch Processing**: Nextflow-powered automated workflows  
✅ **Quality Assessment**: Automatic data quality validation  
✅ **Multiple Methods**: Kriging and IDW interpolation support  
✅ **Cross-Validation**: Statistical validation and performance metrics  
✅ **Web Interface**: User-friendly browser-based control panel  
✅ **Production Ready**: Containerized deployment with monitoring  

## 📞 Support

For technical support and customization:
- Review system logs for error diagnosis
- Check configuration files for parameter tuning
- Monitor resource usage for performance optimization
- Validate input data format and quality

---
**System Version**: CHEAQI Spatial Interpolation v1.0  
**Last Updated**: November 2024  
**Deployment Status**: Production Ready 🚀