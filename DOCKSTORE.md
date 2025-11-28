# Dockstore Integration for CHEAQI Uganda Workflow

## Overview
This repository is configured for [Dockstore](https://dockstore.org/) - a platform for sharing containerized scientific workflows.

## Dockstore Configuration

### Workflow Information
- **Type**: Nextflow Workflow
- **Primary Language**: Nextflow DSL2
- **Container Registry**: Docker Hub / Quay.io
- **Source**: GitHub Repository
- **License**: Open Source

### Workflow Files
- **Primary Descriptor**: `uganda_workflow.nf` (Original workflow)
- **Enhanced Descriptor**: `uganda_enhanced_workflow.nf` (Daily interpolation)
- **Configuration**: `uganda.config`
- **Container**: `Dockerfile`
- **Test Parameters**: `test_uganda.py`

### Dockstore Entry Points
1. **Uganda Basic Workflow**
   - File: `uganda_workflow.nf`
   - Description: Basic spatial interpolation for Uganda environmental data
   - Test: `test.nf`

2. **Uganda Enhanced Workflow** 
   - File: `uganda_enhanced_workflow.nf`
   - Description: Advanced daily interpolation with geostack creation
   - Test: `test_uganda.py`

## Quick Start from Dockstore

### Using Dockstore CLI
```bash
# Install Dockstore CLI
curl -L https://github.com/dockstore/dockstore-cli/releases/download/1.15.0/dockstore -o dockstore
chmod +x dockstore && sudo mv dockstore /usr/local/bin/

# Configure Dockstore
dockstore config

# Launch workflow from Dockstore
dockstore workflow launch --entry github.com/yourusername/cheaqi-uganda-spatial-analysis:main \
  --json test-parameters.json
```

### Using Nextflow directly
```bash
# Run from Dockstore entry
nextflow run dockstore.org/workflows/github.com/yourusername/cheaqi-uganda-spatial-analysis:main \
  -c uganda.config \
  --input_csv data/Uganda_Daily.csv
```

## Metadata for Dockstore

### Workflow Metadata
- **Name**: CHEAQI Uganda Spatial Analysis
- **Description**: Comprehensive Environmental Health and Air Quality Indicators spatial interpolation workflow for Uganda
- **Author**: [Your Name]
- **Version**: 1.0.0
- **DOI**: [To be assigned by Dockstore]

### Scientific Domain
- **Category**: Bioinformatics / Environmental Health
- **Keywords**: spatial-interpolation, environmental-health, air-quality, geospatial, nextflow, docker
- **Species**: Environmental (Uganda region)
- **Data Types**: CSV, GeoTIFF, Spatial

### Input Requirements
- CSV files with coordinate columns (lat/lon)
- Environmental variable columns
- Minimum 10 data points per variable

### Output Products
- Daily interpolated GeoTIFF files
- Multi-day variable geostacks
- Spatial visualization maps
- Processing reports and metadata

## Container Information
- **Base Image**: condaforge/mambaforge:latest
- **Key Libraries**: PyKrige, Rasterio, GDAL, Nextflow
- **Size**: ~2GB (compressed)
- **Platforms**: linux/amd64, linux/arm64

## Citation
When using this workflow, please cite:
```
[Your Name] et al. (2025). CHEAQI Uganda Spatial Analysis Workflow. 
Dockstore. https://dockstore.org/workflows/github.com/yourusername/cheaqi-uganda-spatial-analysis
```