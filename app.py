#!/usr/bin/env python3
"""
CHEAQI Simple CSV Processing Interface
A lightweight web interface for selecting and processing CSV files
"""

from flask import Flask, render_template, request, jsonify, send_file
import pandas as pd
import numpy as np
import os
import json
from pathlib import Path
import sys

app = Flask(__name__)

# Configuration
DATA_DIR = '/app/data'
OUTPUTS_DIR = '/app/outputs'
SCRIPTS_DIR = '/app/scripts'

def detect_coordinate_columns(df):
    """Auto-detect coordinate columns in a DataFrame"""
    lat_patterns = ['lat', 'latitude', 'y', 'northing']
    lon_patterns = ['lon', 'long', 'longitude', 'x', 'easting']
    
    lat_col = None
    lon_col = None
    
    for col in df.columns:
        col_lower = col.lower()
        if any(pattern in col_lower for pattern in lat_patterns):
            lat_col = col
        elif any(pattern in col_lower for pattern in lon_patterns):
            lon_col = col
    
    if lat_col and lon_col:
        return {'latitude': lat_col, 'longitude': lon_col}
    return None

def get_csv_files():
    """Get list of available CSV files"""
    csv_files = []
    if os.path.exists(DATA_DIR):
        for file in os.listdir(DATA_DIR):
            if file.endswith('.csv'):
                file_path = os.path.join(DATA_DIR, file)
                try:
                    # Get basic info about the CSV
                    df = pd.read_csv(file_path, nrows=5)  # Just read first 5 rows for info
                    coords = detect_coordinate_columns(df)
                    info = {
                        'name': file,
                        'path': file_path,
                        'size': os.path.getsize(file_path),
                        'columns': list(df.columns),
                        'rows_preview': len(df),
                        'coordinates': coords,
                        'sample_data': df.head(3).to_dict('records')
                    }
                    csv_files.append(info)
                except Exception as e:
                    csv_files.append({
                        'name': file,
                        'path': file_path,
                        'error': str(e)
                    })
    return csv_files

@app.route('/')
def index():
    """Main page - show available CSV files"""
    csv_files = get_csv_files()
    return render_template('index.html', csv_files=csv_files)

@app.route('/api/files')
def api_get_files():
    """API endpoint to get available CSV files"""
    try:
        csv_files = get_csv_files()
        return jsonify({
            'success': True,
            'files': [f['name'] for f in csv_files if 'error' not in f],
            'details': csv_files
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/csv_info/<filename>')
def csv_info(filename):
    """Get detailed information about a specific CSV file"""
    file_path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(file_path):
        return jsonify({'error': 'File not found'}), 404
    
    try:
        df = pd.read_csv(file_path)
        
        # Auto-detect coordinate columns
        lat_candidates = [col for col in df.columns if any(term in col.lower() for term in ['lat', 'y', 'northing'])]
        lon_candidates = [col for col in df.columns if any(term in col.lower() for term in ['lon', 'lng', 'x', 'easting'])]
        date_candidates = [col for col in df.columns if any(term in col.lower() for term in ['date', 'time', 'day', 'month', 'year'])]
        
        # Get numeric columns for interpolation
        numeric_columns = list(df.select_dtypes(include=[np.number]).columns)
        
        info = {
            'name': filename,
            'shape': df.shape,
            'columns': list(df.columns),
            'numeric_columns': numeric_columns,
            'dtypes': {col: str(dtype) for col, dtype in df.dtypes.items()},
            'sample_data': df.head(5).to_dict('records'),
            'summary': df.describe().to_dict() if len(numeric_columns) > 0 else {},
            'auto_detected': {
                'lat_candidates': lat_candidates,
                'lon_candidates': lon_candidates,
                'date_candidates': date_candidates
            },
            'missing_values': df.isnull().sum().to_dict()
        }
        return jsonify(info)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/variable_selection/<filename>')
def variable_selection(filename):
    """Get variable selection interface data"""
    file_path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(file_path):
        return jsonify({'error': 'File not found'}), 404
    
    try:
        df = pd.read_csv(file_path)
        
        # Column analysis
        column_info = {}
        for col in df.columns:
            col_data = df[col].dropna()
            column_info[col] = {
                'dtype': str(df[col].dtype),
                'non_null_count': len(col_data),
                'null_percentage': (df[col].isnull().sum() / len(df)) * 100,
                'is_numeric': pd.api.types.is_numeric_dtype(df[col]),
                'unique_values': df[col].nunique(),
                'sample_values': col_data.head(3).tolist() if len(col_data) > 0 else []
            }
            
            if pd.api.types.is_numeric_dtype(df[col]) and len(col_data) > 0:
                column_info[col].update({
                    'min': float(col_data.min()),
                    'max': float(col_data.max()),
                    'mean': float(col_data.mean()),
                    'std': float(col_data.std())
                })
        
        # Extract numeric variables for interpolation
        numeric_variables = []
        coordinate_candidates = {'latitude': [], 'longitude': []}
        
        for col, info in column_info.items():
            if info['is_numeric']:
                numeric_variables.append({
                    'name': col,
                    'type': 'numeric',
                    'missing_percentage': info['null_percentage'],
                    'data_points': info['non_null_count'],
                    'min_value': info.get('min', 'N/A'),
                    'max_value': info.get('max', 'N/A'),
                    'mean_value': info.get('mean', 'N/A'),
                    'std_value': info.get('std', 'N/A')
                })
                
                # Check for coordinate patterns
                col_lower = col.lower()
                if any(pattern in col_lower for pattern in ['lat', 'latitude', 'y']):
                    coordinate_candidates['latitude'].append(col)
                elif any(pattern in col_lower for pattern in ['lon', 'longitude', 'long', 'x']):
                    coordinate_candidates['longitude'].append(col)
        
        return jsonify({
            'filename': filename,
            'variables': numeric_variables,
            'coordinates': coordinate_candidates,
            'columns': column_info,
            'total_rows': len(df)
        })
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/process_csv', methods=['POST'])
def process_csv():
    """Process selected CSV file with basic operations"""
    data = request.json
    filename = data.get('filename')
    operation = data.get('operation', 'info')
    
    file_path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(file_path):
        return jsonify({'error': 'File not found'}), 404
    
    try:
        df = pd.read_csv(file_path)
        
        if operation == 'info':
            result = {
                'shape': df.shape,
                'columns': list(df.columns),
                'dtypes': df.dtypes.astype(str).to_dict(),
                'missing_values': df.isnull().sum().to_dict(),
                'sample': df.head(5).to_dict('records')
            }
        elif operation == 'summary':
            result = {
                'numeric_summary': df.describe().to_dict() if df.select_dtypes(include='number').shape[1] > 0 else {},
                'missing_values': df.isnull().sum().to_dict(),
                'shape': df.shape
            }
        elif operation == 'export_clean':
            # Basic cleaning - remove rows with all NaN values
            df_clean = df.dropna(how='all')
            output_path = os.path.join(OUTPUTS_DIR, f"cleaned_{filename}")
            df_clean.to_csv(output_path, index=False)
            result = {
                'message': f'Cleaned CSV saved to outputs/cleaned_{filename}',
                'original_rows': len(df),
                'cleaned_rows': len(df_clean),
                'output_file': f"cleaned_{filename}"
            }
        else:
            result = {'error': 'Unknown operation'}
            
        return jsonify(result)
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/variables/<filename>')
def variable_interface(filename):
    """Variable selection interface"""
    return render_template('variables.html', filename=filename)

@app.route('/api/run_interpolation', methods=['POST'])
def run_interpolation():
    """Run spatial interpolation with selected variables"""
    data = request.json
    filename = data.get('filename')
    config = {
        'lat_column': data.get('lat_column'),
        'lon_column': data.get('lon_column'),
        'variables': data.get('variables', []),
        'method': data.get('method', 'kriging'),
        'resolution': data.get('resolution', 100)
    }
    
    if not filename:
        return jsonify({'error': 'Missing filename parameter'}), 400
        
    if not config['variables']:
        return jsonify({'error': 'No variables selected for interpolation'}), 400
    
    try:
        # Import interpolation libraries
        from pykrige.ok import OrdinaryKriging
        import numpy as np
        import rasterio
        from rasterio.transform import from_bounds
        import matplotlib.pyplot as plt
        import os
        import uuid
        
        # Load data
        file_path = os.path.join(DATA_DIR, filename)
        df = pd.read_csv(file_path)
        
        # Auto-detect coordinates if not provided
        if not config['lat_column'] or not config['lon_column']:
            coords = detect_coordinate_columns(df)
            if coords:
                config['lat_column'] = coords['latitude']
                config['lon_column'] = coords['longitude']
            else:
                return jsonify({'error': 'Could not detect coordinate columns. Please specify lat_column and lon_column.'}), 400
        
        # Validate coordinate columns exist
        missing_cols = []
        if config['lat_column'] not in df.columns:
            missing_cols.append(config['lat_column'])
        if config['lon_column'] not in df.columns:
            missing_cols.append(config['lon_column'])
            
        if missing_cols:
            return jsonify({'error': f'Coordinate columns not found: {", ".join(missing_cols)}'}), 400
        
        # Clean coordinate data
        df_clean = df.dropna(subset=[config['lat_column'], config['lon_column']])
        
        if len(df_clean) < 10:
            return jsonify({'error': f'Insufficient coordinate data: {len(df_clean)} points'}), 400
        
        results = {}
        output_files = []
        
        # Process each variable
        for variable in config['variables']:
            if variable not in df.columns:
                continue
                
            # Get clean data for this variable
            var_data = df_clean.dropna(subset=[variable])
            
            if len(var_data) < 10:
                results[variable] = {'error': f'Insufficient data points: {len(var_data)}'}
                continue
            
            # Extract coordinates and values
            lats = var_data[config['lat_column']].values
            lons = var_data[config['lon_column']].values
            values = var_data[variable].values
            
            # Create interpolation grid
            lat_min, lat_max = lats.min(), lats.max()
            lon_min, lon_max = lons.min(), lons.max()
            
            # Add buffer
            lat_buffer = (lat_max - lat_min) * 0.1
            lon_buffer = (lon_max - lon_min) * 0.1
            
            grid_lats = np.linspace(lat_min - lat_buffer, lat_max + lat_buffer, config['resolution'])
            grid_lons = np.linspace(lon_min - lon_buffer, lon_max + lon_buffer, config['resolution'])
            grid_lon, grid_lat = np.meshgrid(grid_lons, grid_lats)
            
            # Perform interpolation
            method = config['method'].lower()
            
            try:
                if method == 'kriging':
                    ok = OrdinaryKriging(
                        lons, lats, values,
                        variogram_model='linear',
                        verbose=False,
                        enable_plotting=False
                    )
                    z, ss = ok.execute('grid', grid_lons, grid_lats)
                    interpolated = z
                else:  # IDW fallback
                    interpolated = np.zeros_like(grid_lat)
                    for i in range(config['resolution']):
                        for j in range(config['resolution']):
                            distances = np.sqrt((lats - grid_lat[i,j])**2 + (lons - grid_lon[i,j])**2)
                            distances = np.maximum(distances, 1e-10)
                            weights = 1 / (distances ** 2)
                            interpolated[i,j] = np.sum(weights * values) / np.sum(weights)
                
                # Save as GeoTIFF
                run_id = str(uuid.uuid4())[:8]
                output_file = f"{filename.replace('.csv', '')}_{variable}_{run_id}.tif"
                output_path = os.path.join(OUTPUTS_DIR, output_file)
                
                bounds = (grid_lon.min(), grid_lat.min(), grid_lon.max(), grid_lat.max())
                transform = from_bounds(*bounds, config['resolution'], config['resolution'])
                
                with rasterio.open(
                    output_path, 'w',
                    driver='GTiff',
                    height=config['resolution'],
                    width=config['resolution'],
                    count=1,
                    dtype=interpolated.dtype,
                    crs='EPSG:4326',
                    transform=transform,
                ) as dst:
                    dst.write(interpolated, 1)
                
                output_files.append(output_file)
                
                results[variable] = {
                    'status': 'success',
                    'n_points': len(values),
                    'value_range': [float(values.min()), float(values.max())],
                    'method_used': method,
                    'output_file': output_file,
                    'grid_bounds': bounds
                }
                
            except Exception as e:
                results[variable] = {'error': str(e)}
        
        return jsonify({
            'status': 'completed',
            'results': results,
            'output_files': output_files,
            'config': config
        })
        
    except Exception as e:
        return jsonify({'error': f'Interpolation failed: {str(e)}'}), 500

@app.route('/api/run_nextflow', methods=['POST'])
def run_nextflow_workflow():
    """Run Nextflow workflow for batch processing"""
    import subprocess
    import uuid
    
    try:
        data = request.json
        filename = data.get('filename')
        variables = data.get('variables', [])
        lat_column = data.get('lat_column', 'lat')
        lon_column = data.get('lon_column', 'lon')
        method = data.get('method', 'kriging')
        resolution = data.get('resolution', 100)
        cross_validation = data.get('cross_validation', False)
        min_points = data.get('min_points', 10)
        
        if not filename or not variables:
            return jsonify({'error': 'Filename and variables are required'}), 400
        
        # Prepare Nextflow command
        input_path = os.path.join(DATA_DIR, filename)
        variables_str = ','.join(variables)
        workflow_id = str(uuid.uuid4())[:8]
        work_dir = f'/tmp/nextflow_work_{workflow_id}'
        
        # Ensure work directory exists
        os.makedirs(work_dir, exist_ok=True)
        
        nextflow_cmd = [
            'nextflow', 'run', '/app/main.nf',
            '--input_csv', input_path,
            '--variables', variables_str,
            '--lat_column', lat_column,
            '--lon_column', lon_column,
            '--method', method,
            '--resolution', str(resolution),
            '--cross_validation', str(cross_validation).lower(),
            '--min_points', str(min_points),
            '--output_dir', OUTPUTS_DIR,
            '-work-dir', work_dir,
            '-profile', 'conda',
            '-resume'
        ]
        
        # Run Nextflow workflow
        print(f"Running Nextflow workflow: {' '.join(nextflow_cmd)}")
        result = subprocess.run(nextflow_cmd, 
                              capture_output=True, 
                              text=True, 
                              cwd='/app',
                              timeout=3600)  # 1 hour timeout
        
        if result.returncode == 0:
            return jsonify({
                'status': 'success',
                'message': 'Nextflow workflow completed successfully',
                'workflow_id': workflow_id,
                'stdout': result.stdout,
                'output_dir': OUTPUTS_DIR
            })
        else:
            return jsonify({
                'status': 'error',
                'message': 'Nextflow workflow failed',
                'workflow_id': workflow_id,
                'error': result.stderr,
                'stdout': result.stdout
            }), 500
            
    except subprocess.TimeoutExpired:
        return jsonify({'error': 'Workflow timeout (>1 hour)'}), 500
    except Exception as e:
        return jsonify({'error': f'Workflow execution failed: {str(e)}'}), 500

@app.route('/api/workflow_status/<workflow_id>')
def get_workflow_status(workflow_id):
    """Get status of a Nextflow workflow"""
    try:
        # Check for workflow outputs
        work_dir = f'/tmp/nextflow_work_{workflow_id}'
        report_files = [f for f in os.listdir(OUTPUTS_DIR) 
                       if f.startswith('workflow_report_') and f.endswith('.json')]
        
        if report_files:
            latest_report = max(report_files, key=lambda x: os.path.getctime(os.path.join(OUTPUTS_DIR, x)))
            with open(os.path.join(OUTPUTS_DIR, latest_report), 'r') as f:
                report_data = json.load(f)
            
            return jsonify({
                'status': 'completed',
                'workflow_id': workflow_id,
                'report': report_data,
                'report_file': latest_report
            })
        else:
            return jsonify({
                'status': 'running',
                'workflow_id': workflow_id,
                'message': 'Workflow still in progress'
            })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/run_spatial_analysis', methods=['POST'])
def run_spatial_analysis():
    """Run spatial interpolation analysis (legacy endpoint)"""
    data = request.json
    filename = data.get('filename')
    
    # This would integrate with your existing cheaqi_core.py script
    try:
        # Import and run your spatial analysis
        sys.path.append(SCRIPTS_DIR)
        from cheaqi_core import process_spatial_data  # Assuming this function exists
        
        file_path = os.path.join(DATA_DIR, filename)
        result = process_spatial_data(file_path)
        
        return jsonify({'message': 'Spatial analysis completed', 'result': result})
    except ImportError:
        return jsonify({'message': 'Spatial analysis script not available. Please use the web interface or Nextflow workflow.'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/get_all_variables/<filename>')
def get_all_variables(filename):
    """Get all variables with detailed statistics for selection"""
    try:
        file_path = os.path.join(DATA_DIR, filename)
        df = pd.read_csv(file_path)
        
        variables = []
        coordinate_columns = []
        
        for col in df.columns:
            col_data = df[col]
            is_numeric = pd.api.types.is_numeric_dtype(col_data)
            
            variable_info = {
                'name': col,
                'type': str(col_data.dtype),
                'is_numeric': is_numeric,
                'total_count': len(col_data),
                'non_null_count': int(col_data.count()),
                'null_count': int(col_data.isnull().sum()),
                'null_percentage': round((col_data.isnull().sum() / len(df)) * 100, 2),
                'unique_values': int(col_data.nunique()),
                'sample_values': col_data.dropna().head(3).tolist()
            }
            
            # Check if this could be a coordinate column
            col_lower = col.lower()
            is_coordinate = any(term in col_lower for term in ['lat', 'lon', 'x', 'y', 'north', 'east'])
            
            if is_numeric:
                clean_data = col_data.dropna()
                if len(clean_data) > 0:
                    variable_info.update({
                        'min_value': round(float(clean_data.min()), 4),
                        'max_value': round(float(clean_data.max()), 4),
                        'mean_value': round(float(clean_data.mean()), 4),
                        'std_value': round(float(clean_data.std()), 4),
                        'suitable_for_interpolation': col_data.count() >= 10 and col_data.nunique() > 5
                    })
                    
                    # Check if values look like coordinates
                    if is_coordinate or (-90 <= clean_data.min() <= 90 and -180 <= clean_data.max() <= 180):
                        coordinate_columns.append({
                            'name': col,
                            'type': 'latitude' if 'lat' in col_lower else 'longitude' if 'lon' in col_lower else 'coordinate',
                            'range': [float(clean_data.min()), float(clean_data.max())]
                        })
            
            variables.append(variable_info)
        
        return jsonify({
            'filename': filename,
            'total_rows': len(df),
            'variables': variables,
            'coordinate_columns': coordinate_columns,
            'numeric_variables': [v for v in variables if v['is_numeric'] and v.get('suitable_for_interpolation', False)]
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/variable_explorer/<filename>')
def variable_explorer(filename):
    """Enhanced variable selection interface"""
    return render_template('variable_explorer.html', filename=filename)

if __name__ == '__main__':
    # Ensure output directory exists
    os.makedirs(OUTPUTS_DIR, exist_ok=True)
    
    # Run the Flask app
    app.run(host='0.0.0.0', port=8888, debug=True)