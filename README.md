# CHEAQI Uganda Spatial Analysis Workflow

🌍 **Comprehensive Environmental Health and Air Quality Indicators (CHEAQI) - Uganda Focus**

Complete Docker-based spatial analysis workflow for processing environmental and health indicators across Uganda using advanced interpolation techniques and multi-temporal geostack creation.

## Features

### 🌟 Core Capabilities
- **Web-based CSV Processing** - Simple interface for spatial interpolation
- **Variable Selection Interface** - Choose coordinates and variables to interpolate
- **Advanced Spatial Interpolation** - Kriging and IDW algorithms
- **Interactive Configuration** - Point-and-click setup with validation
- **Multiple Output Formats** - GeoTIFF files compatible with GIS software

### 📊 Supported Interpolation Methods
- **Ordinary Kriging** - Optimal for spatially correlated data (recommended)
- **Inverse Distance Weighting (IDW)** - Fast and robust for irregular data

### 🗂️ Input Data Requirements
- CSV files with latitude/longitude coordinates  
- Numeric variables for interpolation
- Geographic coordinate system (WGS84 recommended)
- Minimum 10 data points for reliable interpolation

## Quick Start

### Option A: Local Development
1. **Build and start the service:**
   ```bash
   docker-compose up -d
   ```

### Option B: Run from Dockstore
```bash
# Install Dockstore CLI
curl -L https://github.com/dockstore/dockstore-cli/releases/download/1.15.0/dockstore -o dockstore
chmod +x dockstore && sudo mv dockstore /usr/local/bin/

# Launch workflow from Dockstore
dockstore workflow launch --entry github.com/yourusername/cheaqi-uganda-spatial-analysis:main \
  --json test-parameters.json
```

### Option C: Direct Nextflow from Dockstore
```bash
nextflow run dockstore.org/workflows/github.com/yourusername/cheaqi-uganda-spatial-analysis:main \
  -c uganda.config --input_csv data/Uganda_Daily.csv
```

## Using the Web Interface

2. **Access the web interface:**
   - Open http://localhost:8888 in your browser

3. **Add your CSV data:**
   - Place CSV files in the `data/` directory
   - Refresh the web interface to see new files

4. **Process your data:**
   - Select a CSV file from the list
   - Click "Configure Variables & Run Interpolation"
   - Select coordinate columns and variables to interpolate
   - Configure interpolation settings
   - Run the analysis

## Web Interface Workflow

### Step 1: File Selection
- View all available CSV files in the data directory
- See file information including size, columns, and sample data
- Click on a file to select it

### Step 2: Variable Configuration  
- **Coordinates**: Select latitude and longitude columns
- **Variables**: Choose numeric variables to interpolate
- **Method**: Select Kriging (recommended) or IDW
- **Resolution**: Set output grid resolution (50-300 cells)

### Step 3: Run Interpolation
- Validate configuration before running
- Monitor progress during processing
- View results and output file locations
- Download GeoTIFF files from the outputs directory

## File Structure

```
cheaqi-docker/
├── data/                    # Input CSV files (place your data here)
├── outputs/                 # Generated GeoTIFF interpolation results  
├── scripts/                # Core processing algorithms
├── templates/              # Web interface HTML templates
├── app.py                  # Flask web application
├── docker-compose.yml      # Container configuration
├── environment.yml         # Python dependencies
└── Dockerfile             # Container build instructions
```

## Configuration Options

### Interpolation Parameters
- **Grid Resolution**: 50x50 to 300x300 cells
- **Interpolation Method**: Kriging or IDW
- **Coordinate System**: Automatic detection from input data
- **Output Format**: GeoTIFF (.tif) files

### Data Requirements
✅ **Supported formats**: CSV files with headers  
✅ **Coordinate columns**: Decimal degrees (WGS84)  
✅ **Variable types**: Numeric data (integers, floats)  
✅ **Minimum points**: 10+ recommended for stable interpolation  
✅ **Missing data**: Automatically handled (excluded from analysis)

## Dependencies

### Geospatial Processing
- **GDAL 3.7+** - Geospatial data processing
- **GeoPandas** - Vector data operations  
- **Rasterio** - Raster file creation
- **PyKrige** - Kriging interpolation algorithms
- **Shapely & PyProj** - Geometric operations

### Web Application
- **Flask 2.x** - Web framework
- **Pandas** - CSV data processing
- **NumPy** - Numerical operations

## Troubleshooting

### Build Issues
```bash
# Clean rebuild if needed
docker-compose down
docker-compose build --no-cache cheaqi-web
docker-compose up -d
```

### Common Problems

**No CSV files showing:**
- Ensure CSV files are in the `data/` directory
- Check file permissions (should be readable)
- Refresh the web interface

**Interpolation fails:**
- Verify coordinate columns contain valid decimal degrees
- Ensure selected variables are numeric
- Check for sufficient data points (minimum 10)
- Review coordinate system (should be geographic WGS84)

**Permission errors:**
```bash
# Fix file permissions
chmod -R 755 data/ outputs/
```

**Container not accessible:**
```bash
# Check container status
docker-compose ps
docker logs cheaqi-spatial-web

# Verify port availability
netstat -an | findstr :8888
```

## Output Files

### Generated Results
- **Location**: `outputs/` directory
- **Format**: GeoTIFF (.tif) files
- **Naming**: `{variable_name}_interpolated_{method}_{timestamp}.tif`
- **Coordinate System**: Same as input data
- **Grid Resolution**: As configured (e.g., 100x100 cells)

### Using Output Files
The generated GeoTIFF files can be opened in:
- **QGIS** (recommended free GIS software)
- **ArcGIS** Desktop/Pro  
- **R** (using raster package)
- **Python** (using rasterio)
- Any GIS software supporting GeoTIFF

## Performance Guidelines

### Optimal Dataset Sizes
- **Small datasets**: 10-1,000 points (< 1 minute processing)
- **Medium datasets**: 1,000-5,000 points (1-5 minutes)  
- **Large datasets**: 5,000-10,000 points (5-15 minutes)

### Processing Times (approximate)
- **Kriging**: ~30-60 seconds per variable
- **IDW**: ~10-30 seconds per variable  
- **Grid resolution**: Higher resolution = longer processing time

### Memory Requirements
- **Container memory**: 2GB recommended minimum
- **Disk space**: ~10MB per output GeoTIFF file
- **Large datasets**: May require 4GB+ memory

## Example Use Cases

### Environmental Monitoring
- Temperature/precipitation interpolation
- Air quality surface mapping
- Soil property distribution

### Agricultural Applications  
- Yield prediction surfaces
- Soil nutrient mapping
- Irrigation planning

### Health Data Analysis
- Disease prevalence mapping
- Healthcare accessibility analysis
- Environmental health indicators

## Support

**Container logs:**
```bash
docker logs cheaqi-spatial-web
```

**Health check:**
- Web interface should be accessible at http://localhost:8888
- Container should show "healthy" status in `docker-compose ps`

**Common solutions:**
1. Restart container: `docker-compose restart cheaqi-web`
2. Check data format and coordinate system
3. Verify sufficient data points in selected area
4. Test with smaller datasets first