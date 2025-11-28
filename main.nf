#!/usr/bin/env nextflow

/*
========================================================================================
    CHEAQI SPATIAL INTERPOLATION WORKFLOW
========================================================================================
    Github : https://github.com/your-org/cheaqi-workflow
    Documentation: https://your-docs.com
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    WORKFLOW PARAMETERS
========================================================================================
*/

// Global parameter declarations for command-line interface
params.input_dir = '/app/data'
params.output_dir = '/app/outputs' 
params.scripts_dir = '/app/scripts'
params.input_csv = null
params.csv_pattern = '*.csv'
params.lat_column = 'latitude'
params.lon_column = 'longitude'
params.variables = 'temperature,humidity,precipitation'
params.method = 'kriging'
params.resolution = 100
params.cross_validation = true
params.min_points = 10
params.buffer_percent = 0.1
params.output_format = 'geotiff'
params.create_plots = true
params.generate_report = true
params.validation_folds = 5
params.help = false

/*
========================================================================================
    HELP MESSAGE
========================================================================================
*/

def helpMessage() {
    log.info"""
    ========================================================================
                    CHEAQI SPATIAL INTERPOLATION WORKFLOW
    ========================================================================
    
    Usage:
        nextflow run main.nf [options]
    
    Input Options:
        --input_dir DIR         Directory containing CSV files [default: ${params.input_dir}]
        --csv_pattern PATTERN   Pattern to match CSV files [default: ${params.csv_pattern}]
        
    Interpolation Options:
        --lat_column COL        Column name for latitude [default: ${params.lat_column}]
        --lon_column COL        Column name for longitude [default: ${params.lon_column}]
        --variables VARS        Comma-separated variables to interpolate [default: ${params.variables}]
        --method METHOD         Interpolation method (kriging|idw|linear) [default: ${params.method}]
        --resolution RES        Grid resolution [default: ${params.resolution}]
        
    Output Options:
        --output_dir DIR        Output directory [default: ${params.output_dir}]
        --output_format FMT     Output format (geotiff|netcdf) [default: ${params.output_format}]
        --create_plots          Create visualization plots [default: ${params.create_plots}]
        --generate_report       Generate summary report [default: ${params.generate_report}]
        
    Validation Options:
        --cross_validation      Perform cross-validation [default: ${params.cross_validation}]
        --validation_folds N    Number of CV folds [default: ${params.validation_folds}]
        
    Other Options:
        --help                  Show this help message and exit
    
    Examples:
        # Basic run with default parameters
        nextflow run main.nf
        
        # Custom variables and method
        nextflow run main.nf --variables "temp,rainfall,ndvi" --method idw
        
        # High resolution interpolation
        nextflow run main.nf --resolution 200 --method kriging
    
    ========================================================================
    """
}

// Show help message if requested
if (params.help) {
    helpMessage()
    exit 0
}

/*
========================================================================================
    WORKFLOW VALIDATION
========================================================================================
*/

// Validate parameters
if (!params.lat_column || !params.lon_column) {
    log.error "ERROR: Latitude and longitude columns must be specified"
    exit 1
}

if (!params.variables) {
    log.error "ERROR: At least one variable must be specified for interpolation"
    exit 1
}

// Parse variables list
variables_list = params.variables.split(',').collect{ it.trim() }

log.info """
========================================================================
                    CHEAQI WORKFLOW STARTED
========================================================================
Input Directory     : ${params.input_dir}
Output Directory    : ${params.output_dir}
CSV Pattern         : ${params.csv_pattern}
Coordinate Columns  : ${params.lat_column}, ${params.lon_column}
Variables           : ${variables_list.join(', ')}
Method              : ${params.method}
Resolution          : ${params.resolution}x${params.resolution}
Cross Validation    : ${params.cross_validation}
========================================================================
"""

/*
========================================================================================
    PROCESSES
========================================================================================
*/

process VALIDATE_CSV {
    tag "validate_${csv_file.simpleName}"
    
    input:
    path csv_file
    
    output:
    tuple path(csv_file), stdout, emit: validated_csv
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import sys
    import json
    
    try:
        # Load CSV
        df = pd.read_csv('${csv_file}')
        
        # Check required columns
        required_cols = ['${params.lat_column}', '${params.lon_column}']
        if '${params.variables}' and '${params.variables}' != 'null':
            variables = '${params.variables}'.split(',')
            required_cols.extend(variables)
        
        missing_cols = [col for col in required_cols if col not in df.columns]
        
        if missing_cols:
            result = {
                'status': 'failed', 
                'reason': f'Missing columns: {missing_cols}',
                'available_columns': list(df.columns)
            }
        else:
            # Check data quality
            lat_data = df['${params.lat_column}'].dropna()
            lon_data = df['${params.lon_column}'].dropna()
            
            if len(lat_data) < ${params.min_points}:
                result = {
                    'status': 'failed',
                    'reason': f'Insufficient coordinate data points: {len(lat_data)} < ${params.min_points}'
                }
            else:
                # Count valid data for each variable
                var_stats = {}
                for var in '${variables_list.join("','")}'.split("','"):
                    if var in df.columns:
                        valid_count = df[var].dropna().count()
                        var_stats[var] = {
                            'valid_points': int(valid_count),
                            'missing_percent': float((df[var].isnull().sum() / len(df)) * 100)
                        }
                
                result = {
                    'status': 'success',
                    'shape': df.shape,
                    'coordinate_points': int(len(lat_data)),
                    'lat_range': [float(lat_data.min()), float(lat_data.max())],
                    'lon_range': [float(lon_data.min()), float(lon_data.max())],
                    'variables': var_stats
                }
        
        print(json.dumps(result))
        
    except Exception as e:
        result = {'status': 'failed', 'reason': str(e)}
        print(json.dumps(result))
        sys.exit(1)
    """
}

process SPATIAL_INTERPOLATION {
    tag "interpolate_${csv_file.simpleName}"
    publishDir "${params.output_dir}/interpolated", mode: 'copy'
    
    input:
    tuple path(csv_file), val(validation_info)
    
    output:
    tuple path(csv_file), path("*.tif"), path("*_report.json"), emit: interpolation_results
    path "*.png", optional: true, emit: plots
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np
    import json
    import matplotlib.pyplot as plt
    import seaborn as sns
    from pathlib import Path
    import rasterio
    from rasterio.transform import from_bounds
    from pykrige.ok import OrdinaryKriging
    from scipy.spatial.distance import cdist
    import warnings
    warnings.filterwarnings('ignore')
    
    # Load and parse validation info
    validation = json.loads('${validation_info}')
    
    if validation['status'] != 'success':
        print(f"Skipping ${csv_file.simpleName}: {validation['reason']}")
        # Create empty output files to satisfy Nextflow
        Path("${csv_file.simpleName}_skip.txt").touch()
        exit(0)
    
    # Load CSV data
    df = pd.read_csv('${csv_file}')
    base_name = '${csv_file.simpleName}'
    
    # Clean coordinate data
    df_clean = df.dropna(subset=['${params.lat_column}', '${params.lon_column}'])
    
    results = {}
    output_files = []
    
    # Process each variable
    for variable in '${variables_list.join("','")}'.split("','"):
        if variable not in df.columns:
            continue
            
        print(f"Processing {variable} for {base_name}...")
        
        # Get clean data for this variable
        var_data = df_clean.dropna(subset=[variable])
        
        if len(var_data) < ${params.min_points}:
            print(f"Insufficient data for {variable}: {len(var_data)} points")
            continue
        
        # Extract coordinates and values
        lats = var_data['${params.lat_column}'].values
        lons = var_data['${params.lon_column}'].values
        values = var_data[variable].values
        
        # Create interpolation grid
        lat_min, lat_max = lats.min(), lats.max()
        lon_min, lon_max = lons.min(), lons.max()
        
        # Add buffer
        lat_buffer = (lat_max - lat_min) * ${params.buffer_percent}
        lon_buffer = (lon_max - lon_min) * ${params.buffer_percent}
        
        grid_lats = np.linspace(lat_min - lat_buffer, lat_max + lat_buffer, ${params.resolution})
        grid_lons = np.linspace(lon_min - lon_buffer, lon_max + lon_buffer, ${params.resolution})
        grid_lon, grid_lat = np.meshgrid(grid_lons, grid_lats)
        
        # Perform interpolation
        method = '${params.method}'.lower()
        
        if method == 'kriging':
            try:
                ok = OrdinaryKriging(
                    lons, lats, values,
                    variogram_model='linear',
                    verbose=False,
                    enable_plotting=False
                )
                z, ss = ok.execute('grid', grid_lons, grid_lats)
                interpolated = z
                print(f"Kriging completed for {variable}")
            except Exception as e:
                print(f"Kriging failed for {variable}: {e}, using IDW")
                method = 'idw'
        
        if method == 'idw':
            # Inverse Distance Weighting
            interpolated = np.zeros_like(grid_lat)
            
            for i in range(${params.resolution}):
                for j in range(${params.resolution}):
                    distances = np.sqrt((lats - grid_lat[i,j])**2 + (lons - grid_lon[i,j])**2)
                    distances = np.maximum(distances, 1e-10)  # Avoid division by zero
                    weights = 1 / (distances ** 2)
                    interpolated[i,j] = np.sum(weights * values) / np.sum(weights)
            
            print(f"IDW completed for {variable}")
        
        # Save as GeoTIFF
        output_file = f"{base_name}_{variable}_interpolated.tif"
        bounds = (grid_lon.min(), grid_lat.min(), grid_lon.max(), grid_lat.max())
        transform = from_bounds(*bounds, ${params.resolution}, ${params.resolution})
        
        with rasterio.open(
            output_file, 'w',
            driver='GTiff',
            height=${params.resolution},
            width=${params.resolution},
            count=1,
            dtype=interpolated.dtype,
            crs='EPSG:4326',
            transform=transform,
        ) as dst:
            dst.write(interpolated, 1)
        
        output_files.append(output_file)
        
        # Store results for reporting
        results[variable] = {
            'n_points': len(values),
            'value_range': [float(values.min()), float(values.max())],
            'value_mean': float(values.mean()),
            'value_std': float(values.std()),
            'method_used': method,
            'output_file': output_file,
            'grid_bounds': bounds
        }
        
        # Create visualization if requested
        if ${params.create_plots}:
            fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
            
            # Interpolated surface
            im1 = ax1.contourf(grid_lon, grid_lat, interpolated, levels=20, cmap='viridis')
            ax1.scatter(lons, lats, c=values, s=30, cmap='viridis', edgecolors='white', linewidth=0.5)
            ax1.set_title(f'{variable} - Interpolated Surface ({method.upper()})')
            ax1.set_xlabel('Longitude')
            ax1.set_ylabel('Latitude')
            plt.colorbar(im1, ax=ax1, shrink=0.8)
            
            # Original data points
            scatter = ax2.scatter(lons, lats, c=values, s=50, cmap='plasma', edgecolors='black', linewidth=0.5)
            ax2.set_title(f'{variable} - Original Data Points (n={len(values)})')
            ax2.set_xlabel('Longitude')
            ax2.set_ylabel('Latitude')
            plt.colorbar(scatter, ax=ax2, shrink=0.8)
            
            plt.tight_layout()
            plt.savefig(f'{base_name}_{variable}_interpolation.png', dpi=300, bbox_inches='tight')
            plt.close()
    
    # Generate report
    report = {
        'dataset': base_name,
        'processing_timestamp': pd.Timestamp.now().isoformat(),
        'configuration': {
            'lat_column': '${params.lat_column}',
            'lon_column': '${params.lon_column}',
            'method': '${params.method}',
            'resolution': ${params.resolution},
            'buffer_percent': ${params.buffer_percent}
        },
        'input_data': {
            'total_rows': len(df),
            'coordinate_points': len(df_clean),
            'coordinate_bounds': {
                'lat_range': [float(df_clean['${params.lat_column}'].min()), float(df_clean['${params.lat_column}'].max())],
                'lon_range': [float(df_clean['${params.lon_column}'].min()), float(df_clean['${params.lon_column}'].max())]
            }
        },
        'results': results,
        'output_files': output_files
    }
    
    with open(f'{base_name}_report.json', 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"Completed processing {base_name}: {len(results)} variables interpolated")
    """
}

process CROSS_VALIDATION {
    tag "cv_${csv_file.simpleName}"
    publishDir "${params.output_dir}/validation", mode: 'copy'
    
    when:
    params.cross_validation
    
    input:
    tuple path(csv_file), path(tif_files), path(report_file)
    
    output:
    path "*_cv_results.json", emit: cv_results
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np
    import json
    from sklearn.model_selection import KFold
    from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
    from pykrige.ok import OrdinaryKriging
    import warnings
    warnings.filterwarnings('ignore')
    
    # Load report to get processing info
    with open('${report_file}', 'r') as f:
        report = json.load(f)
    
    if not report['results']:
        print("No interpolation results found for cross-validation")
        # Create empty CV results
        cv_results = {'status': 'skipped', 'reason': 'No interpolation results'}
        with open('${csv_file.simpleName}_cv_results.json', 'w') as f:
            json.dump(cv_results, f, indent=2)
        exit(0)
    
    # Load CSV data
    df = pd.read_csv('${csv_file}')
    df_clean = df.dropna(subset=['${params.lat_column}', '${params.lon_column}'])
    
    cv_results = {}
    
    # Perform cross-validation for each variable
    for variable in report['results'].keys():
        if variable not in df.columns:
            continue
            
        print(f"Cross-validating {variable}...")
        
        var_data = df_clean.dropna(subset=[variable])
        
        if len(var_data) < ${params.validation_folds}:
            print(f"Insufficient data for CV: {len(var_data)} < ${params.validation_folds}")
            continue
        
        lats = var_data['${params.lat_column}'].values
        lons = var_data['${params.lon_column}'].values  
        values = var_data[variable].values
        
        # K-fold cross-validation
        kf = KFold(n_splits=${params.validation_folds}, shuffle=True, random_state=42)
        
        cv_scores = {
            'rmse': [],
            'mae': [],
            'r2': [],
            'fold_sizes': []
        }
        
        for train_idx, test_idx in kf.split(values):
            # Split data
            train_lons, test_lons = lons[train_idx], lons[test_idx]
            train_lats, test_lats = lats[train_idx], lats[test_idx]
            train_vals, test_vals = values[train_idx], values[test_idx]
            
            try:
                # Train interpolator on training data
                ok = OrdinaryKriging(
                    train_lons, train_lats, train_vals,
                    variogram_model='linear',
                    verbose=False,
                    enable_plotting=False
                )
                
                # Predict on test points
                predicted, _ = ok.execute('points', test_lons, test_lats)
                
                # Calculate metrics
                rmse = np.sqrt(mean_squared_error(test_vals, predicted))
                mae = mean_absolute_error(test_vals, predicted)
                r2 = r2_score(test_vals, predicted)
                
                cv_scores['rmse'].append(rmse)
                cv_scores['mae'].append(mae)
                cv_scores['r2'].append(r2)
                cv_scores['fold_sizes'].append(len(test_vals))
                
            except Exception as e:
                print(f"CV fold failed for {variable}: {e}")
                continue
        
        if cv_scores['rmse']:
            cv_results[variable] = {
                'n_folds': len(cv_scores['rmse']),
                'rmse_mean': float(np.mean(cv_scores['rmse'])),
                'rmse_std': float(np.std(cv_scores['rmse'])),
                'mae_mean': float(np.mean(cv_scores['mae'])),
                'mae_std': float(np.std(cv_scores['mae'])),
                'r2_mean': float(np.mean(cv_scores['r2'])),
                'r2_std': float(np.std(cv_scores['r2'])),
                'fold_scores': {
                    'rmse': [float(x) for x in cv_scores['rmse']],
                    'mae': [float(x) for x in cv_scores['mae']],
                    'r2': [float(x) for x in cv_scores['r2']]
                }
            }
        
        print(f"CV completed for {variable}: RMSE={np.mean(cv_scores['rmse']):.3f}±{np.std(cv_scores['rmse']):.3f}")
    
    # Save CV results
    final_results = {
        'dataset': '${csv_file.simpleName}',
        'cv_folds': ${params.validation_folds},
        'timestamp': pd.Timestamp.now().isoformat(),
        'results': cv_results
    }
    
    with open('${csv_file.simpleName}_cv_results.json', 'w') as f:
        json.dump(final_results, f, indent=2)
    
    print(f"Cross-validation completed for ${csv_file.simpleName}")
    """
}

process GENERATE_SUMMARY {
    tag "summary"
    publishDir params.output_dir, mode: 'copy'
    
    input:
    path interpolation_reports
    path cv_results, stageAs: 'cv_results/*'
    
    output:
    path "workflow_summary_*.html", emit: summary_report
    path "workflow_summary_*.json", emit: summary_json
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import json
    from pathlib import Path
    import matplotlib.pyplot as plt
    import seaborn as sns
    import base64
    from io import BytesIO
    
    # Collect all interpolation reports
    report_files = [f for f in Path('.').glob('*_report.json')]
    cv_files = list(Path('cv_results').glob('*_cv_results.json')) if Path('cv_results').exists() else []
    
    # Load and combine reports
    all_reports = []
    for report_file in report_files:
        with open(report_file, 'r') as f:
            report = json.load(f)
            all_reports.append(report)
    
    # Load CV results
    all_cv_results = {}
    for cv_file in cv_files:
        with open(cv_file, 'r') as f:
            cv_data = json.load(f)
            dataset_name = cv_data.get('dataset', cv_file.stem.replace('_cv_results', ''))
            all_cv_results[dataset_name] = cv_data
    
    # Generate summary statistics
    summary_stats = {
        'workflow_info': {
            'timestamp': pd.Timestamp.now().isoformat(),
            'total_datasets': len(all_reports),
            'total_variables_processed': sum(len(r['results']) for r in all_reports),
            'configuration': {
                'method': '${params.method}',
                'resolution': ${params.resolution},
                'cross_validation': ${params.cross_validation}
            }
        },
        'dataset_summaries': [],
        'overall_statistics': {}
    }
    
    # Process each dataset
    all_points = []
    all_variables = set()
    
    for report in all_reports:
        dataset_name = report['dataset']
        dataset_summary = {
            'dataset': dataset_name,
            'total_rows': report['input_data']['total_rows'],
            'coordinate_points': report['input_data']['coordinate_points'],
            'variables_processed': len(report['results']),
            'variables': list(report['results'].keys()),
            'bounds': report['input_data']['coordinate_bounds']
        }
        
        # Add CV results if available
        if dataset_name in all_cv_results and 'results' in all_cv_results[dataset_name]:
            cv_summary = {}
            for var, cv_data in all_cv_results[dataset_name]['results'].items():
                cv_summary[var] = {
                    'rmse': cv_data['rmse_mean'],
                    'r2': cv_data['r2_mean']
                }
            dataset_summary['cross_validation'] = cv_summary
        
        summary_stats['dataset_summaries'].append(dataset_summary)
        
        # Collect for overall stats
        all_points.append(report['input_data']['coordinate_points'])
        all_variables.update(report['results'].keys())
    
    # Overall statistics
    if all_points:
        summary_stats['overall_statistics'] = {
            'total_data_points': sum(all_points),
            'avg_points_per_dataset': sum(all_points) / len(all_points),
            'unique_variables': list(all_variables),
            'datasets_with_cv': len(all_cv_results)
        }
    
    # Save JSON summary
    timestamp = pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')
    json_file = f'workflow_summary_{timestamp}.json'
    with open(json_file, 'w') as f:
        json.dump(summary_stats, f, indent=2)
    
    # Generate HTML report
    html_content = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>CHEAQI Workflow Summary</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }}
            .container {{ background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
            .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin-bottom: 30px; }}
            .metric {{ background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0; }}
            .dataset {{ border: 1px solid #ddd; padding: 20px; border-radius: 5px; margin: 15px 0; }}
            .success {{ color: #28a745; }}
            .warning {{ color: #ffc107; }}
            .error {{ color: #dc3545; }}
            table {{ width: 100%; border-collapse: collapse; margin: 15px 0; }}
            th, td {{ padding: 10px; border: 1px solid #ddd; text-align: left; }}
            th {{ background-color: #f8f9fa; }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🌍 CHEAQI Spatial Interpolation Workflow Summary</h1>
                <p>Generated: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            </div>
            
            <div class="metric">
                <h2>📊 Overview</h2>
                <p><strong>Total Datasets Processed:</strong> {len(all_reports)}</p>
                <p><strong>Total Variables Interpolated:</strong> {sum(len(r['results']) for r in all_reports)}</p>
                <p><strong>Interpolation Method:</strong> {params.method}</p>
                <p><strong>Grid Resolution:</strong> {params.resolution}×{params.resolution}</p>
                <p><strong>Cross-Validation:</strong> {'Enabled' if params.cross_validation else 'Disabled'}</p>
            </div>
    '''
    
    # Add dataset details
    html_content += '''
            <h2>📂 Dataset Processing Results</h2>
            <table>
                <tr>
                    <th>Dataset</th>
                    <th>Data Points</th>
                    <th>Variables</th>
                    <th>Status</th>
                </tr>
    '''
    
    for summary in summary_stats['dataset_summaries']:
        status = f"<span class='success'>✅ {summary['variables_processed']} processed</span>"
        variables_str = ', '.join(summary['variables'][:3])
        if len(summary['variables']) > 3:
            variables_str += f" (+{len(summary['variables'])-3} more)"
        
        html_content += f'''
                <tr>
                    <td>{summary['dataset']}</td>
                    <td>{summary['coordinate_points']:,}</td>
                    <td>{variables_str}</td>
                    <td>{status}</td>
                </tr>
        '''
    
    html_content += '''
            </table>
    '''
    
    # Add CV results if available
    if all_cv_results:
        html_content += '''
            <h2>🎯 Cross-Validation Results</h2>
            <table>
                <tr>
                    <th>Dataset</th>
                    <th>Variable</th>
                    <th>RMSE</th>
                    <th>R²</th>
                </tr>
        '''
        
        for dataset_name, cv_data in all_cv_results.items():
            if 'results' in cv_data:
                for var, metrics in cv_data['results'].items():
                    html_content += f'''
                    <tr>
                        <td>{dataset_name}</td>
                        <td>{var}</td>
                        <td>{metrics['rmse_mean']:.3f} ± {metrics['rmse_std']:.3f}</td>
                        <td>{metrics['r2_mean']:.3f} ± {metrics['r2_std']:.3f}</td>
                    </tr>
                    '''
        
        html_content += '</table>'
    
    html_content += '''
            <div class="metric">
                <h2>📁 Output Files</h2>
                <p>All interpolated surfaces have been saved as GeoTIFF files in the outputs directory.</p>
                <p>Each dataset includes:</p>
                <ul>
                    <li>Interpolated raster files (*.tif)</li>
                    <li>Processing reports (*.json)</li>
    '''
    
    if params.create_plots:
        html_content += '<li>Visualization plots (*.png)</li>'
    
    if params.cross_validation:
        html_content += '<li>Cross-validation results</li>'
    
    html_content += '''
                </ul>
            </div>
        </div>
    </body>
    </html>
    '''
    
    # Save HTML report
    html_file = f'workflow_summary_{timestamp}.html'
    with open(html_file, 'w') as f:
        f.write(html_content)
    
    print(f"Summary report generated: {html_file}")
    print(f"Summary data saved: {json_file}")
    """
}

/*
========================================================================================
    WORKFLOW
========================================================================================
*/

workflow {
    // Handle single CSV file input or pattern-based input
    if (params.input_csv) {
        // Single file mode (called from Flask app)
        csv_files = Channel.fromPath(params.input_csv)
            .ifEmpty { error "Input CSV file not found: ${params.input_csv}" }
    } else {
        // Batch mode (process all CSV files matching pattern)
        csv_files = Channel
            .fromPath("${params.input_dir}/${params.csv_pattern}")
            .ifEmpty { error "No CSV files found in ${params.input_dir} matching pattern ${params.csv_pattern}" }
    }
    
    // Validate CSV files
    VALIDATE_CSV(csv_files)
    
    // Filter successful validations and run interpolation
    valid_files = VALIDATE_CSV.out.validated_csv
        .filter { csv, validation_json -> 
            validation = new groovy.json.JsonSlurper().parseText(validation_json)
            return validation.status == 'success'
        }
    
    // Run spatial interpolation
    SPATIAL_INTERPOLATION(valid_files)
    
    // Cross-validation (optional)
    if (params.cross_validation) {
        CROSS_VALIDATION(SPATIAL_INTERPOLATION.out.interpolation_results)
    }
    
    // Generate summary report
    cv_results = params.cross_validation ? 
        CROSS_VALIDATION.out.cv_results.collect() : 
        Channel.empty()
    
    GENERATE_SUMMARY(
        SPATIAL_INTERPOLATION.out.interpolation_results.map { csv, tifs, report -> report }.collect(),
        cv_results.ifEmpty([])
    )
}

/*
========================================================================================
    COMPLETION MESSAGE
========================================================================================
*/

workflow.onComplete {
    log.info """
    ========================================================================
                        CHEAQI WORKFLOW COMPLETED
    ========================================================================
    Status      : ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Work Dir    : ${workflow.workDir}
    Duration    : ${workflow.duration}
    Exit Status : ${workflow.exitStatus}
    Error Report: ${workflow.errorReport ?: 'None'}
    ========================================================================
    """
    
    if (workflow.success) {
        log.info "Results available in: ${params.output_dir}"
        log.info "Summary report: ${params.output_dir}/workflow_summary_*.html"
    }
}

workflow.onError {
    log.error "Workflow execution failed: ${workflow.errorMessage}"
}