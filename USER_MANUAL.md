# 🌍 CHEAQI Interactive Docker Workflow - User Manual

## 🚀 Essential Commands to Run the System

### **🎯 Quick Start - Main Commands**
```bash
# 1. Start the complete interactive system
docker compose up -d --build

# 2. Access the web interfaces
# Main Interface:    http://localhost:8888
# Real-time Monitor: http://localhost:8890

# 3. Stop the system
docker compose down
```

### **📋 Available Services**
- **📊 Main Web Interface** (Port 8888): Interactive CSV processing
- **📈 Real-time Monitor** (Port 8890): Live system monitoring  
- **📁 File Server** (Port 8080): File access (optional)

## 🔧 Detailed Command Reference

### **Service Management Commands**
```bash
# View running services
docker compose ps

# View service logs  
docker compose logs cheaqi-web
docker compose logs cheaqi-monitor

# Restart specific service
docker compose restart cheaqi-web

# Rebuild after changes
docker compose up -d --build cheaqi-web
```

### **Direct Workflow Execution**
```bash
# Access container shell
docker exec -it cheaqi-spatial-web bash

# Run Nextflow workflow directly
docker exec -it cheaqi-spatial-web nextflow run main.nf \
  --input_csv /app/data/Kenya_Daily.csv \
  --variables "T2M,TP,NDVI" \
  --method kriging \
  --resolution 100

# Copy data to/from containers
docker cp your-data.csv cheaqi-spatial-web:/app/data/
docker cp cheaqi-spatial-web:/app/outputs ./local-outputs
```

## 🌐 Using the Interactive Web Interface

### **Step 1: Access the System**
1. **Start Services:** `docker compose up -d --build`
2. **Open Browser:** http://localhost:8888  
3. **View Available Data:** You'll see CSV files in the interface

### First Steps Checklist
- ✅ Verify your CSV files are in the `data/` directory
- ✅ Check that files contain coordinate columns (latitude/longitude)  
- ✅ Ensure environmental variables are properly formatted
- ✅ Review data for missing values or obvious errors

## 📊 Understanding Your Data

### CSV File Requirements
Your CSV files should contain:
- **Coordinate Columns**: Latitude and Longitude (decimal degrees)
- **Environmental Variables**: Numeric data for interpolation
- **Date/Time Columns**: For temporal analysis (optional)
- **Quality Indicators**: Data completeness and accuracy measures

### Sample Data Format
```csv
Date,Latitude,Longitude,Temperature,Humidity,Precipitation,Station_ID
2024-01-01,-1.2921,36.8219,25.5,68.2,0.0,KE001
2024-01-01,-0.3031,36.0800,24.8,71.5,2.3,KE002
2024-01-01,0.5143,35.2698,26.1,65.8,0.0,KE003
```

## 🎛️ Main Interface Guide

### Dashboard Overview
```
┌─────────────────────────────────────────────────────────────┐
│                     CHEAQI Dashboard                        │
├─────────────────────────────────────────────────────────────┤
│  🗂️ Available Datasets                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Select CSV File: [Dropdown Menu ▼]                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  🚀 Start Spatial Interpolation:                           │
│  ┌─────────────────┐  ┌─────────────────────────────────┐   │
│  │ 🔍 Explore &    │  │ 🎯 Quick Configuration         │   │
│  │ Select Variables │  │                                │   │
│  └─────────────────┘  └─────────────────────────────────┘   │
│                                                             │
│  ⚡ Batch Processing with Nextflow:                        │
│  ┌─────────────────┐  ┌─────────────────────────────────┐   │
│  │ 🔄 Run Nextflow │  │ 📊 Check Workflow Status       │   │
│  │ Workflow        │  │                                 │   │
│  └─────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Navigation Options
- **🔍 Explore & Select Variables**: Advanced variable analysis and selection
- **🎯 Quick Configuration**: Simplified variable selection for quick processing
- **🔄 Run Nextflow Workflow**: Automated batch processing
- **📊 Check Workflow Status**: Monitor ongoing processing tasks

## 🔍 Variable Selection Workflows

### Option 1: Advanced Variable Explorer

#### Step-by-Step Guide
1. **Select Dataset**: Choose your CSV file from the dropdown
2. **Open Explorer**: Click "🔍 Explore & Select Variables"
3. **Analyze Variables**: Review the comprehensive variable analysis

#### Variable Explorer Features
```
┌─────────────────────────────────────────────────────────────┐
│                Variable Explorer Interface                  │
├─────────────────────────────────────────────────────────────┤
│  🎛️ Filter Controls                                         │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐   │
│  │ Variable Type ▼ │ │ Data Quality ▼  │ │ Category ▼   │   │
│  └─────────────────┘ └─────────────────┘ └──────────────┘   │
│                                                             │
│  📊 Variable Grid                                           │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ ☑️ Temperature    │ 📈 25.3±3.2°C    │ 🟢 Excellent    │ │
│  │ ☑️ Humidity       │ 📈 68.5±12.1%    │ 🟡 Good         │ │
│  │ ☐ Precipitation   │ 📈 2.1±8.7mm     │ 🔴 Poor         │ │
│  │ ☑️ Pressure       │ 📈 1013±5.2hPa   │ 🟢 Excellent    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  🎯 Processing Options                                      │
│  ┌─────────────────┐ ┌─────────────────────────────────────┐ │
│  │ Single Analysis │ │ Batch Workflow Processing           │ │
│  └─────────────────┘ └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### Filter Options
- **Variable Type**: Numeric, Categorical, Date, Coordinate
- **Data Quality**: Complete, Partial, Poor (based on missing values)
- **Category**: Environmental, Meteorological, Atmospheric, Derived
- **Statistical Range**: Min/Max value filtering

#### Variable Information Display
Each variable shows:
- **Selection Checkbox**: Include/exclude in analysis
- **Statistical Summary**: Mean ± Standard deviation
- **Data Quality**: Color-coded quality indicator
- **Missing Values**: Percentage of missing data
- **Outlier Count**: Number of statistical outliers detected

### Option 2: Quick Configuration

#### When to Use
- Simple, fast variable selection
- Working with familiar datasets
- Quick testing and validation

#### Interface Overview
```
┌─────────────────────────────────────────────────────────────┐
│                Quick Variable Selection                     │
├─────────────────────────────────────────────────────────────┤
│  📍 Coordinate Columns                                      │
│  Latitude:  [Dropdown ▼]  Longitude: [Dropdown ▼]         │
│                                                             │
│  📊 Environmental Variables                                 │
│  ☑️ Temperature     ☐ Wind Speed      ☑️ Humidity          │
│  ☑️ Precipitation   ☐ Pressure        ☐ Solar Radiation    │
│                                                             │
│  ⚙️ Method Selection                                        │
│  ◉ Kriging  ◯ IDW (Inverse Distance Weighting)            │
│                                                             │
│  🚀 [Run Interpolation]                                     │
└─────────────────────────────────────────────────────────────┘
```

## ⚙️ Interpolation Methods

### Kriging (Recommended)
**Best for**: Environmental data with spatial correlation
**Advantages**:
- Provides uncertainty estimates
- Optimal statistical interpolation
- Handles sparse data well
- Accounts for spatial relationships

**When to Use**:
- Temperature, humidity, precipitation mapping
- Data with clear spatial patterns
- Need for uncertainty quantification

### IDW (Inverse Distance Weighting)
**Best for**: Quick interpolation with simple assumptions  
**Advantages**:
- Fast computation
- Simple to understand
- No statistical assumptions required
- Good for dense data

**When to Use**:
- Rapid preliminary analysis
- Dense measurement networks
- Simple spatial patterns

## 🔄 Batch Processing with Nextflow

### Setting Up Batch Processing
1. **Prepare Multiple Files**: Place CSV files in `data/` directory
2. **Launch Workflow**: Click "🔄 Run Nextflow Workflow"
3. **Configure Options**: Select processing parameters
4. **Monitor Progress**: Use "📊 Check Workflow Status"

### Batch Processing Interface
```
┌─────────────────────────────────────────────────────────────┐
│                Nextflow Batch Configuration                 │
├─────────────────────────────────────────────────────────────┤
│  📁 Dataset Selection                                       │
│  ☑️ Gambia_Daily.csv      ☑️ Kenya_Daily.csv               │
│  ☑️ Mozambique_Daily.csv  ☑️ Uganda_Daily.csv              │
│  ☐ South Africa.csv                                        │
│                                                             │
│  ⚙️ Processing Parameters                                   │
│  Method: ◉ Kriging ◯ IDW                                   │
│  Validation: ☑️ Cross-validation ☑️ Test split             │
│  Output: ☑️ Maps ☑️ Reports ☑️ Statistics                  │
│                                                             │
│  🚀 [Launch Batch Processing]                               │
└─────────────────────────────────────────────────────────────┘
```

### Monitoring Batch Jobs
The workflow status interface shows:
- **Job Progress**: Completion percentage for each file
- **Processing Stage**: Current step (validation, interpolation, reporting)
- **Resource Usage**: CPU and memory consumption  
- **Error Status**: Any processing errors or warnings
- **Estimated Time**: Remaining processing time

## 📊 Understanding Results

### Single Interpolation Results
After processing, you'll receive:

#### 1. Interpolated Maps
- **Format**: GeoTIFF raster files
- **Content**: Spatially interpolated values
- **Resolution**: Configurable grid spacing
- **Projection**: Geographic coordinates (WGS84)

#### 2. Validation Reports
```
Cross-Validation Results:
├── RMSE: 2.34°C (Root Mean Square Error)
├── MAE: 1.89°C (Mean Absolute Error)  
├── R²: 0.92 (Coefficient of Determination)
└── Bias: 0.12°C (Systematic error)

Spatial Coverage:
├── Interpolated Area: 125,432 km²
├── Data Points Used: 847 measurements
├── Grid Resolution: 0.01° (~1.1 km)
└── Uncertainty Range: ±1.2°C (95% CI)
```

#### 3. Quality Metrics
- **Data Coverage**: Percentage of area with reliable interpolation
- **Uncertainty Maps**: Spatial distribution of prediction uncertainty
- **Residual Analysis**: Difference between predicted and observed values
- **Outlier Detection**: Identification of suspicious data points

### Batch Processing Results

#### Organized Output Structure
```
outputs/
├── batch_results_[timestamp]/
│   ├── Gambia/
│   │   ├── interpolated_temperature.tif
│   │   ├── interpolated_humidity.tif
│   │   ├── validation_report.html
│   │   └── statistics_summary.json
│   ├── Kenya/
│   │   └── [similar structure]
│   ├── comparative_analysis.html
│   └── batch_summary_report.pdf
└── workflow_logs/
    ├── nextflow.log
    └── execution_timeline.html
```

#### Comparative Analysis Features
- **Multi-country Comparisons**: Side-by-side analysis
- **Temporal Trends**: If date columns are present
- **Quality Assessment**: Comparative validation metrics
- **Spatial Patterns**: Regional variation analysis

## 📈 Advanced Features

### Data Quality Assessment
The system automatically evaluates:
- **Missing Value Patterns**: Temporal and spatial gaps
- **Outlier Detection**: Statistical and spatial outliers
- **Data Consistency**: Cross-variable validation
- **Coordinate Validation**: Geographic bounds checking

### Variable Relationships
- **Correlation Analysis**: Inter-variable relationships  
- **Principal Component Analysis**: Data dimension reduction
- **Clustering Analysis**: Identification of data patterns
- **Trend Detection**: Temporal and spatial trends

### Custom Interpolation Parameters
Advanced users can configure:
- **Grid Resolution**: Spatial detail level (0.01° to 0.1°)
- **Kriging Model**: Spherical, exponential, or Gaussian
- **IDW Power Parameter**: Distance decay rate (1-5)
- **Cross-Validation**: K-fold validation (3-10 folds)

## 🔧 Troubleshooting Guide

### Common Issues and Solutions

#### 1. File Loading Problems
**Problem**: "File not found" or loading errors
**Solutions**:
- Verify file is in `data/` directory
- Check file format (must be CSV)
- Ensure proper file permissions
- Validate CSV structure and encoding

#### 2. Coordinate Issues
**Problem**: No coordinates detected or invalid coordinates
**Solutions**:
- Check column names (lat, latitude, lon, longitude)
- Verify coordinate format (decimal degrees)
- Ensure coordinates are within valid ranges (-90 to 90, -180 to 180)
- Remove any non-numeric characters

#### 3. Processing Errors
**Problem**: Interpolation fails or produces poor results
**Solutions**:
- Check data quality (remove excessive outliers)
- Verify sufficient data points (minimum 20-30 points)
- Ensure spatial distribution (not all points clustered)
- Review variable selection (remove constant variables)

#### 4. Performance Issues
**Problem**: Slow processing or memory errors
**Solutions**:
- Reduce grid resolution for large areas
- Process smaller datasets or time periods
- Close other applications to free memory
- Use batch processing for multiple files

### Error Messages Reference

| Error Message | Cause | Solution |
|--------------|--------|----------|
| "No numeric columns found" | All variables are non-numeric | Check data types, remove text columns |
| "Insufficient data points" | Less than 10 coordinate pairs | Add more data or use different dataset |
| "Coordinate validation failed" | Invalid lat/lon values | Check coordinate column format |
| "Interpolation failed" | Mathematical error in kriging | Try IDW method or check data quality |
| "Memory allocation error" | Insufficient RAM | Reduce grid resolution or dataset size |

## 💡 Best Practices

### Data Preparation Tips
1. **Clean Data**: Remove obvious errors and outliers
2. **Check Coverage**: Ensure spatial distribution across study area
3. **Validate Coordinates**: Verify all points fall within expected region
4. **Document Variables**: Keep track of units and measurement methods

### Processing Recommendations
1. **Start Small**: Test with subset before full analysis
2. **Compare Methods**: Try both Kriging and IDW for comparison
3. **Validate Results**: Always review validation metrics
4. **Save Settings**: Document successful parameter combinations

### Quality Assurance
1. **Visual Inspection**: Always examine output maps
2. **Statistical Validation**: Review RMSE and R² values
3. **Cross-Reference**: Compare with known patterns or other sources
4. **Documentation**: Keep analysis logs and parameter records

## 🎓 Learning Resources

### Understanding Spatial Interpolation
- **Kriging Theory**: Geostatistical optimal prediction method
- **Variogram Analysis**: Understanding spatial correlation structure  
- **Cross-Validation**: Statistical validation of interpolation quality
- **Uncertainty Quantification**: Understanding prediction confidence

### Further Reading
- Spatial interpolation theory and applications
- Geostatistics and kriging methodology
- Environmental data analysis techniques
- GIS and remote sensing integration

---

## 📞 Getting Help

### Documentation Resources
- **PRODUCTION_GUIDE.md**: Deployment and configuration details
- **ARCHITECTURE.md**: Technical system documentation
- **README.md**: Quick start and overview
- **System Logs**: Real-time processing information

### Support Workflow
1. **Check Error Messages**: Review specific error details
2. **Consult Troubleshooting**: Follow systematic problem-solving steps
3. **Review Logs**: Examine system logs for detailed information
4. **Test with Sample Data**: Verify system functionality with known datasets

---

**User Manual Version**: 1.0  
**Last Updated**: November 2024  
**System Compatibility**: CHEAQI Spatial Interpolation v1.0  
**User Level**: Beginner to Advanced ✅