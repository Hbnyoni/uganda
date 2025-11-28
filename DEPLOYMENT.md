#  CHEAQI Container Deployment Guide

## Quick Deployment Steps

### 1. **Prepare Your Environment**
```cmd
# Windows Command Prompt or PowerShell
cd C:\Users\user\cheaqi-docker

# Copy your notebook to the notebooks directory (if not already done)
copy "path\to\your\notebook.ipynb" ".\notebooks\"

# Add your CSV data files to the data directory
copy "path\to\your\data.csv" ".\data\"
```

### 2. **Build and Deploy** 

**Option A: Full Production Build**
```cmd
# Build the complete geospatial container (takes 10-15 minutes)
.\manage.bat build

# Start Jupyter Lab
.\manage.bat start

# Access at: http://localhost:8888
```

**Option B: Quick Test Build** 
```cmd
# Fast test build (2-3 minutes) - for testing basic functionality
docker-compose -f docker-compose.test.yml up -d

# Access at: http://localhost:8889
```

### 3. **Verify Installation**
```cmd
# Check container status
.\manage.bat status

# View container logs
.\manage.bat logs

# Enter container for debugging
.\manage.bat shell
```

## 🎯 What You Get

### **Interactive Jupyter Environment**
- Full geospatial Python stack (GDAL, rasterio, fiona, etc.)
- Interactive widgets for parameter selection
- Real-time processing feedback
- Automatic output generation

### **Three Interpolation Methods**
1. **GDAL Grid**: Fastest, enterprise-grade
2. **Python IDW**: Flexible, pure Python
3. **PyKrige**: Advanced geostatistical

### **Multiple Output Formats**
- Individual GeoTIFF rasters per date
- Master multi-band GeoTIFF stack  
- NetCDF time series cubes
- CSV metadata tracking

### **Batch Processing Capability**
```cmd
# Process CSV files automatically
.\manage.bat process sample_data.csv
```

## 📊 Usage Patterns

### **Interactive Analysis Workflow**
1. Upload CSV to `data/` folder
2. Open notebook in Jupyter Lab (http://localhost:8888)
3. Use widgets to select columns and parameters
4. Run interpolation and view results
5. Download outputs from `outputs/` folder

### **Batch Processing Workflow**  
1. Configure parameters in `scripts/config.json`
2. Run: `.\manage.bat process your_data.csv`
3. Monitor progress in logs
4. Collect results from `outputs/` folder

### **Development Workflow**
1. Enter container: `.\manage.bat shell`
2. Modify processing scripts
3. Test with sample data
4. Deploy changes by rebuilding

## 🛠️ Container Architecture

```
┌─────────────────────────────────────────┐
│           Host System (Windows)          │
│  ┌─────────────────────────────────────┐ │
│  │        CHEAQI Container             │ │
│  │  ┌─────────────────────────────────┐│ │
│  │  │     Jupyter Lab Server          ││ │
│  │  │     (Port 8888)                 ││ │
│  │  └─────────────────────────────────┘│ │
│  │  ┌─────────────────────────────────┐│ │
│  │  │   Python Geospatial Stack      ││ │
│  │  │   - GDAL/OGR                    ││ │
│  │  │   - rasterio/fiona              ││ │
│  │  │   - pandas/numpy                ││ │
│  │  │   - scipy/pykrige               ││ │
│  │  └─────────────────────────────────┘│ │
│  └─────────────────────────────────────┘ │
│           ↕ Volume Mounts                │
│  ┌─────────────────────────────────────┐ │
│  │  data/     notebooks/    outputs/   │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

## 🔧 Configuration Options

### **Environment Variables** (`environment.yml`)
- Python 3.11 with conda-forge packages
- Full geospatial stack
- Interactive widgets
- Scientific computing libraries

### **Processing Parameters** (`scripts/config.json`)
```json
{
  "air_quality": {
    "variables": ["pm25", "pm10", "no2", "o3"],
    "method": "python_idw_kdtree", 
    "cell_size": 500.0
  }
}
```

### **Docker Compose Profiles**
- `default`: Jupyter Lab only
- `fileserver`: + HTTP file browser (port 8080)
- `batch`: + Background processor

## 📈 Performance Optimization

### **For Large Datasets**
```yaml
# Increase container memory
deploy:
  resources:
    limits:
      memory: 8G
    reservations:
      memory: 4G
```

### **For High-Resolution Grids**
- Use `gdal_grid` method (fastest)
- Process in temporal chunks
- Increase parallel jobs parameter

### **For Many Variables**
- Use batch processing mode
- Configure processing queues
- Monitor disk space in `outputs/`

## 🚨 Troubleshooting

### **Build Failures**
```cmd
# Clean Docker environment
.\manage.bat clean

# Rebuild from scratch  
.\manage.bat build

# Check Docker resources
docker system df
```

### **Runtime Issues**
```cmd
# Check container logs
.\manage.bat logs

# Enter container for debugging
.\manage.bat shell
source activate cheaqi
python -c "import gdal; print('GDAL OK')"
```

### **Memory Issues**
- Increase Docker Desktop memory allocation
- Reduce grid resolution (`cell_size` parameter)
- Process smaller date ranges

### **Permission Issues**
- Ensure `data/` and `outputs/` directories are writable
- On Linux/macOS: `chmod +x manage.sh`

## 📊 Example Workflows

### **Air Quality Monitoring**
```csv
longitude,latitude,datetime,pm25,pm10,no2
-122.4194,37.7749,2023-01-01 12:00,12.5,18.2,25.3
```
**→ Results**: Daily PM2.5/PM10/NO2 raster surfaces

### **Environmental Assessment**
```csv
site_lon,site_lat,sample_date,temperature,ph,conductivity
-105.2705,40.0150,2023-06-15,18.5,7.2,450
```
**→ Results**: Multi-parameter environmental surfaces

### **Climate Analysis**  
```csv
x,y,date,temp_max,temp_min,precipitation
-120.5,35.2,2023-07-01,32.1,18.9,0.0
```
**→ Results**: Climate variable interpolation surfaces

## 🎉 Next Steps

1. **Start with sample data**: Use provided `data/sample_data.csv`
2. **Customize for your data**: Modify column mappings
3. **Explore methods**: Compare GDAL vs Python vs PyKrige
4. **Scale up**: Process your full datasets
5. **Integrate**: Connect with your existing workflows

## 📚 Additional Resources

- [Docker Desktop Installation](https://www.docker.com/products/docker-desktop)
- [GDAL Documentation](https://gdal.org/)
- [Jupyter Lab User Guide](https://jupyterlab.readthedocs.io/)
- [Spatial Interpolation Theory](https://en.wikipedia.org/wiki/Spatial_interpolation)

---

**Container tested and ready for deployment! 🚀**

Your CHEAQI spatial interpolation workbench is now fully containerized and ready for production use.