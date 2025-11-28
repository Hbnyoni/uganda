# 🏗️ CHEAQI System Architecture Documentation

## 📐 System Overview

The CHEAQI Spatial Interpolation System is built on a microservices architecture using Docker containers, providing scalable geospatial data processing capabilities with advanced web interfaces.

## 🔧 Core Components

### 1. Container Infrastructure
```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │            cheaqi-spatial-web                       │    │
│  │  ┌─────────────────┐  ┌─────────────────────────┐   │    │
│  │  │   Flask App     │  │     Nextflow Engine     │   │    │
│  │  │   (Port 5000)   │  │    (Java 17 + NF)      │   │    │
│  │  └─────────────────┘  └─────────────────────────┘   │    │
│  │  ┌─────────────────────────────────────────────────┐   │    │
│  │  │        Mambaforge Environment                   │   │    │
│  │  │  Python 3.11 + Scientific Stack                │   │    │
│  │  └─────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 2. Application Layer Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                     Web Interface                           │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │    Main      │  │   Variable   │  │    Variable      │   │
│  │  Dashboard   │  │  Selection   │  │   Explorer       │   │
│  │              │  │   (Simple)   │  │  (Advanced)      │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      Flask API                              │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │    File      │  │    Data      │  │   Interpolation  │   │
│  │  Management  │  │  Analysis    │  │    Processing    │   │
│  │              │  │              │  │                  │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                   Processing Layer                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │   Single     │  │   Nextflow   │  │    Quality       │   │
│  │Interpolation │  │   Workflow   │  │  Validation      │   │
│  │              │  │   Engine     │  │                  │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Data Flow Architecture

### Input Processing Pipeline
```
CSV Files → Data Validation → Variable Analysis → Selection Interface
    │             │                │                     │
    │             ├── Quality Check ├── Statistical      ├── User Selection
    │             ├── Format Valid. ├── Profiling        ├── Filter Options
    │             └── Schema Check  └── Type Detection   └── Batch Config
    │
    └── Processed Data → Interpolation Engine → Output Generation
                              │                      │
                         ┌────┴─────┐           ┌────┴─────┐
                         │ Kriging  │           │   Maps   │
                         │   IDW    │           │ Reports  │
                         └──────────┘           └──────────┘
```

### Workflow Execution Model
```
┌─────────────────────────────────────────────────────────────┐
│                 Execution Pathways                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Single Processing:                                         │
│  User Interface → Flask API → Python Script → Results      │
│                                                             │
│  Batch Processing:                                          │
│  User Interface → Flask API → Nextflow → Parallel Tasks    │
│                      │            │           │             │
│                      │            ├─ Task 1 ──┤             │
│                      │            ├─ Task 2 ──┤             │
│                      │            └─ Task N ──┘             │
│                      │                                      │
│                      └─── Results Aggregation → Reports     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🗃️ Data Management Architecture

### Storage Structure
```
/app/
├── data/                    # Input CSV datasets
│   ├── [country]_Daily.csv  # Timestamped environmental data
│   └── validation/          # Test datasets
├── outputs/                 # Generated results
│   ├── interpolated/        # Spatial interpolation results
│   ├── validation/          # Cross-validation reports
│   └── workflows/           # Nextflow execution logs
├── scripts/                 # Core processing modules
│   ├── cheaqi_core.py      # Main interpolation engine
│   ├── batch_process.py    # Batch processing utilities
│   └── config.json         # System configuration
└── templates/              # Web interface components
    ├── index.html          # Main dashboard
    ├── variables.html      # Simple variable selection
    └── variable_explorer.html # Advanced variable interface
```

### Database Schema (In-Memory)
```
CSV Data Model:
├── Temporal Dimension
│   ├── Date/DateTime columns (auto-detected)
│   └── Time-based aggregations
├── Spatial Dimension  
│   ├── Latitude coordinates
│   ├── Longitude coordinates
│   └── Location identifiers
├── Environmental Variables
│   ├── Meteorological (temp, humidity, pressure)
│   ├── Atmospheric (precipitation, wind)
│   └── Derived indicators (indices, ratios)
└── Data Quality Metrics
    ├── Missing value patterns
    ├── Outlier detection results
    └── Statistical distributions
```

## 🔄 Processing Engine Architecture

### Spatial Interpolation Core
```python
class SpatialInterpolationEngine:
    ├── KrigingProcessor
    │   ├── VariogramAnalysis
    │   ├── ModelFitting (spherical, exponential, gaussian)
    │   └── OptimalPrediction
    ├── IDWProcessor  
    │   ├── DistanceCalculation
    │   ├── WeightComputation
    │   └── ValueInterpolation
    ├── ValidationEngine
    │   ├── CrossValidation (k-fold)
    │   ├── MetricsCalculation (RMSE, MAE, R²)
    │   └── StatisticalTests
    └── OutputGeneration
        ├── RasterOutput (.tif)
        ├── VectorOutput (.geojson)
        └── ReportGeneration (.html)
```

### Nextflow Workflow Structure
```groovy
workflow SPATIAL_INTERPOLATION {
    input:
        path csvFile
        val variables
        val method
    
    main:
        // Data preprocessing
        VALIDATE_DATA(csvFile)
        
        // Variable selection and filtering
        SELECT_VARIABLES(VALIDATE_DATA.out, variables)
        
        // Parallel interpolation
        INTERPOLATE_KRIGING(SELECT_VARIABLES.out)
        INTERPOLATE_IDW(SELECT_VARIABLES.out)
        
        // Cross-validation
        CROSS_VALIDATE(SELECT_VARIABLES.out, method)
        
        // Report generation
        GENERATE_REPORT(INTERPOLATE_KRIGING.out, 
                       INTERPOLATE_IDW.out, 
                       CROSS_VALIDATE.out)
    
    emit:
        results = GENERATE_REPORT.out
        validation = CROSS_VALIDATE.out
}
```

## 🌐 API Architecture

### RESTful Endpoints Design
```
/api/
├── files/                   # File Management
│   ├── GET /               # List available files
│   ├── POST /upload        # Upload new files
│   └── DELETE /{filename}  # Remove files
├── analysis/               # Data Analysis
│   ├── GET /variables/{file}      # Get variable list
│   ├── GET /statistics/{file}     # Statistical summary
│   └── GET /quality/{file}        # Quality assessment
├── processing/            # Interpolation Processing  
│   ├── POST /interpolate         # Single interpolation
│   ├── POST /batch              # Batch processing
│   └── GET /status/{job_id}     # Processing status
└── results/              # Output Management
    ├── GET /download/{result_id} # Download results
    ├── GET /preview/{result_id}  # Preview outputs
    └── DELETE /{result_id}       # Clean up results
```

### WebSocket Integration (Future)
```javascript
// Real-time processing updates
ws://localhost:8080/ws/
├── /progress     # Processing progress updates
├── /status       # System status monitoring  
└── /logs         # Real-time log streaming
```

## 🔧 Configuration Management

### Environment Configuration Layers
```
1. Container Environment (Dockerfile)
   ├── Base OS (Ubuntu/Conda)
   ├── System packages (GDAL, Java)
   └── Python environment

2. Application Configuration (config.json)
   ├── Interpolation parameters
   ├── Validation settings  
   └── Output specifications

3. Workflow Configuration (nextflow.config)
   ├── Execution profiles
   ├── Resource allocation
   └── Process definitions

4. Runtime Configuration (docker-compose.yml)
   ├── Port mappings
   ├── Volume mounts
   └── Environment variables
```

## 🚀 Deployment Architecture

### Development vs Production
```
Development:                Production:
├── Hot reload enabled      ├── Optimized builds
├── Debug logging          ├── Error logging only
├── Single container       ├── Multi-instance
└── Local volumes          └── Persistent storage

Load Balancing (Production):
┌─────────────────────────────────────────┐
│            Load Balancer                │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ Instance 1  │  │   Instance N    │   │
│  │ Port 8080   │  │   Port 808N     │   │
│  └─────────────┘  └─────────────────┘   │
├─────────────────────────────────────────┤
│         Shared Storage                  │
│    (Data + Outputs + Cache)             │
└─────────────────────────────────────────┘
```

## 📈 Scalability Considerations

### Horizontal Scaling Points
1. **Flask Application**: Multiple container instances
2. **Nextflow Workers**: Distributed task execution  
3. **Storage Layer**: Shared filesystem or object storage
4. **Database**: External database for metadata/logs

### Performance Optimization
- **Caching Strategy**: Results and intermediate computations
- **Memory Management**: Efficient data structure usage
- **Parallel Processing**: Multi-core interpolation algorithms
- **Resource Pooling**: Connection and process pools

## 🛡️ Security Architecture

### Security Layers
```
1. Network Security
   ├── Container isolation
   ├── Port restriction
   └── Internal networking

2. Application Security  
   ├── Input validation
   ├── File type checking
   └── Resource limits

3. Data Security
   ├── Access controls
   ├── Audit logging
   └── Secure file handling
```

## 🔍 Monitoring & Observability

### Logging Architecture
```
Application Logs → Container Logs → Host Logs → Centralized Logging
     │                  │              │             │
     ├── Flask logs     ├── stdout     ├── Docker    ├── ELK Stack
     ├── Nextflow logs  ├── stderr     ├── System    ├── Prometheus
     └── Error logs     └── Exit codes └── Hardware  └── Grafana
```

---
**Architecture Version**: 1.0  
**Last Updated**: November 2024  
**Status**: Production Architecture Complete ✅