#!/usr/bin/env nextflow

/*
========================================================================================
    CHEAQI UGANDA-FOCUSED ENHANCED SPATIAL INTERPOLATION WORKFLOW
========================================================================================
    Enhanced Features:
    - Daily spatial interpolation per variable
    - GeoTIFF creation with proper georeferencing
    - Variable-specific and multi-variable geostacks
    - Comprehensive spatial distribution analysis
    - Multiple interpolation methods (Kriging, IDW, RBF)
========================================================================================
*/

nextflow.enable.dsl = 2

// Uganda-specific parameters
params.input_csv = '/app/data/Uganda_Daily.csv'
params.country_filter = 'Uganda'
params.output_dir = '/app/outputs/uganda_enhanced_analysis'
params.scripts_dir = '/app/scripts'

// Target variables for analysis
params.target_variables = ['NDVI', 'pm25', 'no2', 'WRND', 'EH', 'EM', 'T2M', 'RH', 'LST', 'ET', 'TP', 'BLH']

// Spatial parameters
params.lat_column = 'lat'
params.lon_column = 'lon'
params.date_column = 'date'
params.method = 'kriging'
params.resolution = 100
params.buffer_percent = 0.2

// Enhanced interpolation parameters
params.enable_interpolation = true
params.max_days_per_variable = 50  // Limit days for performance
params.interpolation_method = 'kriging'  // kriging, idw, rbf
params.grid_resolution = 0.01  // degrees
params.variogram_model = 'spherical'  // linear, power, gaussian, spherical, exponential

// GeoTIFF and Geostack parameters
params.create_geotiff = true
params.create_geostack = true
params.output_crs = 'EPSG:4326'
params.compress_geotiff = 'lzw'

// Enhanced visualization parameters
params.create_maps = true
params.create_animations = true
params.create_spatial_distribution = true
params.animation_fps = 2
params.map_style = 'viridis'

/*
========================================================================================
    PROCESSES
========================================================================================
*/

process UGANDA_DATA_PREPARATION {
    tag "Uganda data prep"
    
    input:
    path csv_file
    
    output:
    path "uganda_prepared.csv", emit: prepared_csv
    path "variable_stats.json", emit: stats
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np
    import json
    from datetime import datetime
    
    # Load and filter Uganda data
    print("🇺🇬 Loading Uganda Daily data...")
    df = pd.read_csv('${csv_file}')
    
    # Filter for Uganda only
    uganda_df = df[df['country'] == '${params.country_filter}'].copy()
    print(f"Uganda records: {len(uganda_df)}")
    
    # Target variables
    target_vars = ['NDVI', 'pm25', 'no2', 'WRND', 'EH', 'EM', 'T2M', 'RH', 'LST', 'ET', 'TP', 'BLH']
    required_cols = ['${params.lat_column}', '${params.lon_column}', '${params.date_column}'] + target_vars
    
    # Check available variables
    available_vars = [var for var in target_vars if var in uganda_df.columns]
    missing_vars = [var for var in target_vars if var not in uganda_df.columns]
    
    print(f"✅ Available variables: {available_vars}")
    if missing_vars:
        print(f"❌ Missing variables: {missing_vars}")
    
    # Filter for available columns only
    cols_to_keep = ['id', 'country', 'lat', 'lon', 'date'] + available_vars
    uganda_clean = uganda_df[cols_to_keep].copy()
    
    # Remove rows with missing coordinates
    uganda_clean = uganda_clean.dropna(subset=['lat', 'lon'])
    
    # Convert date column with flexible parsing
    uganda_clean['date'] = pd.to_datetime(uganda_clean['date'], dayfirst=True, errors='coerce')
    
    # Generate statistics
    stats = {
        'total_records': len(uganda_clean),
        'date_range': {
            'start': uganda_clean['date'].min().isoformat(),
            'end': uganda_clean['date'].max().isoformat()
        },
        'spatial_extent': {
            'lat_min': float(uganda_clean['lat'].min()),
            'lat_max': float(uganda_clean['lat'].max()),
            'lon_min': float(uganda_clean['lon'].min()),
            'lon_max': float(uganda_clean['lon'].max())
        },
        'variables': {}
    }
    
    # Variable statistics
    for var in available_vars:
        if var in uganda_clean.columns:
            valid_data = uganda_clean[var].dropna()
            stats['variables'][var] = {
                'count': len(valid_data),
                'mean': float(valid_data.mean()) if len(valid_data) > 0 else None,
                'std': float(valid_data.std()) if len(valid_data) > 0 else None,
                'min': float(valid_data.min()) if len(valid_data) > 0 else None,
                'max': float(valid_data.max()) if len(valid_data) > 0 else None
            }
    
    # Save prepared data
    uganda_clean.to_csv('uganda_prepared.csv', index=False)
    
    # Save statistics
    with open('variable_stats.json', 'w') as f:
        json.dump(stats, f, indent=2)
    
    print(f"📍 Prepared Uganda dataset: {len(uganda_clean)} records")
    print(f"🌍 Variables ready for analysis: {available_vars}")
    """
}

process DAILY_SPATIAL_INTERPOLATION {
    tag "Daily Interpolation: \${variable}"
    
    input:
    path prepared_csv
    each variable
    
    output:
    path "uganda_\${variable}_daily_*.tif", emit: daily_rasters
    path "uganda_\${variable}_interpolation_log.json", emit: interpolation_log
    path "uganda_\${variable}_spatial_stats.json", emit: spatial_stats
    
    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import numpy as np
    from pykrige.ok import OrdinaryKriging
    from scipy.spatial.distance import cdist
    from scipy.interpolate import Rbf
    import rasterio
    from rasterio.transform import from_bounds
    from rasterio.crs import CRS
    import json
    from datetime import datetime, timedelta
    import warnings
    warnings.filterwarnings('ignore')
    
    # Load prepared data
    df = pd.read_csv('${prepared_csv}')
    variable = '${variable}'
    
    print(f"🔍 Processing daily interpolation for variable: {variable}")
    
    # Convert date column to datetime with flexible parsing
    df['date'] = pd.to_datetime(df['date'], dayfirst=True, errors='coerce')
    
    # Filter valid data for this variable (including valid dates)
    valid_data = df.dropna(subset=[variable, 'lat', 'lon', 'date']).copy()
    
    if len(valid_data) < 10:
        print(f"❌ Insufficient data for {variable}: {len(valid_data)} points")
        # Create empty outputs
        with open(f'uganda_{variable}_interpolation_log.json', 'w') as f:
            json.dump({'error': f'Insufficient data: {len(valid_data)} points'}, f)
        with open(f'uganda_{variable}_spatial_stats.json', 'w') as f:
            json.dump({'error': f'Insufficient data: {len(valid_data)} points'}, f)
        exit(1)
    
    print(f"✅ Valid data points for {variable}: {len(valid_data)}")
    
    # Get spatial extent with buffer
    lat_min, lat_max = valid_data['lat'].min(), valid_data['lat'].max()
    lon_min, lon_max = valid_data['lon'].min(), valid_data['lon'].max()
    
    lat_buffer = (lat_max - lat_min) * ${params.buffer_percent}
    lon_buffer = (lon_max - lon_min) * ${params.buffer_percent}
    
    # Create high-resolution interpolation grid
    grid_resolution = ${params.grid_resolution}
    
    # Calculate grid dimensions
    n_lat = int((lat_max - lat_min + 2*lat_buffer) / grid_resolution) + 1
    n_lon = int((lon_max - lon_min + 2*lon_buffer) / grid_resolution) + 1
    
    # Limit grid size for performance
    n_lat = min(n_lat, 500)
    n_lon = min(n_lon, 500)
    
    grid_lat = np.linspace(lat_min - lat_buffer, lat_max + lat_buffer, n_lat)
    grid_lon = np.linspace(lon_min - lon_buffer, lon_max + lon_buffer, n_lon)
    grid_lon_2d, grid_lat_2d = np.meshgrid(grid_lon, grid_lat)
    
    # Group by date for daily interpolation
    dates = sorted(valid_data['date'].dt.date.unique())
    max_days = min(len(dates), ${params.max_days_per_variable})
    selected_dates = dates[:max_days]
    
    print(f"📅 Processing {len(selected_dates)} days out of {len(dates)} available")
    
    interpolation_log = {
        'variable': variable,
        'total_available_dates': len(dates),
        'processed_dates': len(selected_dates),
        'successful_interpolations': 0,
        'failed_interpolations': 0,
        'interpolation_method': '${params.interpolation_method}',
        'grid_resolution': grid_resolution,
        'grid_dimensions': [n_lat, n_lon],
        'spatial_extent': {
            'lat_min': float(lat_min - lat_buffer),
            'lat_max': float(lat_max + lat_buffer),
            'lon_min': float(lon_min - lon_buffer),
            'lon_max': float(lon_max + lon_buffer)
        },
        'daily_results': {}
    }
    
    spatial_stats = {
        'variable': variable,
        'overall_stats': {},
        'daily_stats': {},
        'interpolation_quality': {}
    }
    
    # Define interpolation function
    def perform_interpolation(coords, values, method='${params.interpolation_method}'):
        try:
            if method == 'kriging':
                ok = OrdinaryKriging(
                    coords[:, 0], coords[:, 1], values,
                    variogram_model='${params.variogram_model}',
                    verbose=False,
                    enable_plotting=False,
                    coordinates_type='geographic'
                )
                z, ss = ok.execute('grid', grid_lon, grid_lat)
                return z, ss
            elif method == 'rbf':
                rbf = Rbf(coords[:, 0], coords[:, 1], values, function='multiquadric')
                z = rbf(grid_lon_2d, grid_lat_2d)
                return z, None
            elif method == 'idw':
                # Inverse Distance Weighting
                z = np.zeros_like(grid_lon_2d)
                for i in range(len(grid_lat)):
                    for j in range(len(grid_lon)):
                        distances = cdist([(grid_lon[j], grid_lat[i])], coords)[0]
                        # Avoid division by zero
                        distances[distances == 0] = 1e-10
                        weights = 1 / (distances ** 2)
                        z[i, j] = np.sum(weights * values) / np.sum(weights)
                return z, None
        except Exception as e:
            print(f"Interpolation error: {e}")
            return None, None
    
    for i, date in enumerate(selected_dates):
        try:
            date_str = str(date)
            daily_data = valid_data[valid_data['date'].dt.date == date]
            
            if len(daily_data) < 5:
                interpolation_log['daily_results'][date_str] = {
                    'interpolated': False,
                    'error': f'Insufficient points: {len(daily_data)}'
                }
                interpolation_log['failed_interpolations'] += 1
                continue
                
            print(f"  📅 Processing {date_str}: {len(daily_data)} points")
            
            # Prepare coordinates and values
            coords = daily_data[['lon', 'lat']].values
            values = daily_data[variable].values
            
            # Perform interpolation
            z, variance = perform_interpolation(coords, values)
            
            if z is None:
                interpolation_log['daily_results'][date_str] = {
                    'interpolated': False,
                    'error': 'Interpolation failed'
                }
                interpolation_log['failed_interpolations'] += 1
                continue
            
            # Create GeoTIFF with proper georeferencing
            transform = from_bounds(
                grid_lon.min(), grid_lat.min(),
                grid_lon.max(), grid_lat.max(),
                len(grid_lon), len(grid_lat)
            )
            
            output_file = f'uganda_{variable}_daily_{date_str}.tif'
            
            # Create comprehensive metadata
            metadata = {
                'variable': variable,
                'date': date_str,
                'interpolation_method': '${params.interpolation_method}',
                'grid_resolution_degrees': float(grid_resolution),
                'data_points_used': len(daily_data),
                'spatial_extent': {
                    'lat_min': float(grid_lat.min()),
                    'lat_max': float(grid_lat.max()),
                    'lon_min': float(grid_lon.min()),
                    'lon_max': float(grid_lon.max())
                }
            }
            
            with rasterio.open(
                output_file, 'w',
                driver='GTiff',
                height=len(grid_lat), width=len(grid_lon),
                count=1, dtype=np.float32,
                crs=CRS.from_epsg(4326),
                transform=transform,
                compress='${params.compress_geotiff}',
                tiled=True,
                blockxsize=256,
                blockysize=256
            ) as dst:
                dst.write(z.astype(np.float32), 1)
                dst.set_band_description(1, f'Uganda {variable} - {date_str}')
                dst.update_tags(**{f'META_{k}': str(v) for k, v in metadata.items()})
            
            # Calculate comprehensive statistics
            z_valid = z[~np.isnan(z)]
            original_stats = {
                'mean': float(values.mean()),
                'std': float(values.std()),
                'min': float(values.min()),
                'max': float(values.max()),
                'median': float(np.median(values))
            }
            
            interpolated_stats = {
                'mean': float(np.mean(z_valid)) if len(z_valid) > 0 else np.nan,
                'std': float(np.std(z_valid)) if len(z_valid) > 0 else np.nan,
                'min': float(np.min(z_valid)) if len(z_valid) > 0 else np.nan,
                'max': float(np.max(z_valid)) if len(z_valid) > 0 else np.nan,
                'median': float(np.median(z_valid)) if len(z_valid) > 0 else np.nan
            }
            
            # Store results
            interpolation_log['daily_results'][date_str] = {
                'data_points': len(daily_data),
                'interpolated': True,
                'output_file': output_file,
                'grid_cells': z.size,
                'valid_cells': len(z_valid),
                'coverage_percent': float(len(z_valid) / z.size * 100) if z.size > 0 else 0
            }
            
            spatial_stats['daily_stats'][date_str] = {
                'original_data': original_stats,
                'interpolated_surface': interpolated_stats,
                'spatial_coverage': float(len(z_valid) / z.size * 100) if z.size > 0 else 0
            }
            
            interpolation_log['successful_interpolations'] += 1
            print(f"  ✅ Completed {variable} for {date_str} - {len(z_valid):,} valid cells")
            
        except Exception as e:
            error_msg = str(e)
            print(f"  ❌ Failed {variable} for {date_str}: {error_msg}")
            interpolation_log['failed_interpolations'] += 1
            interpolation_log['daily_results'][date_str] = {
                'interpolated': False,
                'error': error_msg
            }
    
    # Calculate overall statistics
    all_original_values = valid_data[variable].values
    spatial_stats['overall_stats'] = {
        'total_data_points': len(valid_data),
        'date_range': {
            'start': str(valid_data['date'].min().date()),
            'end': str(valid_data['date'].max().date())
        },
        'value_distribution': {
            'mean': float(all_original_values.mean()),
            'std': float(all_original_values.std()),
            'min': float(all_original_values.min()),
            'max': float(all_original_values.max()),
            'percentiles': {
                '25': float(np.percentile(all_original_values, 25)),
                '50': float(np.percentile(all_original_values, 50)),
                '75': float(np.percentile(all_original_values, 75))
            }
        }
    }
    
    # Save results
    with open(f'uganda_{variable}_interpolation_log.json', 'w') as f:
        json.dump(interpolation_log, f, indent=2, default=str)
    
    with open(f'uganda_{variable}_spatial_stats.json', 'w') as f:
        json.dump(spatial_stats, f, indent=2, default=str)
    
    success_rate = (interpolation_log['successful_interpolations'] / len(selected_dates) * 100) if len(selected_dates) > 0 else 0
    print(f"🏁 Completed {variable}: {interpolation_log['successful_interpolations']}/{len(selected_dates)} days ({success_rate:.1f}% success rate)")
    """
}

process CREATE_VARIABLE_GEOSTACK {
    tag "Geostack: \${variable}"
    
    input:
    path daily_rasters
    path interpolation_log
    each variable
    
    output:
    path "uganda_\${variable}_geostack.tif", emit: variable_geostack
    path "uganda_\${variable}_geostack_info.json", emit: geostack_info
    
    when:
    params.create_geostack
    
    script:
    """
    #!/usr/bin/env python3
    import rasterio
    import numpy as np
    from glob import glob
    import json
    from datetime import datetime
    import warnings
    warnings.filterwarnings('ignore')
    
    variable = '${variable}'
    print(f"📚 Creating geostack for {variable}")
    
    # Find all daily rasters for this variable
    raster_pattern = f'uganda_{variable}_daily_*.tif'
    raster_files = sorted(glob(raster_pattern))
    
    if not raster_files:
        print(f"No raster files found for {variable}")
        # Create empty outputs
        with open(f'uganda_{variable}_geostack_info.json', 'w') as f:
            json.dump({'error': f'No raster files found for {variable}'}, f)
        exit(0)
    
    print(f"Found {len(raster_files)} daily rasters for {variable}")
    
    # Read the first raster to get dimensions and metadata
    with rasterio.open(raster_files[0]) as src:
        profile = src.profile.copy()
        transform = src.transform
        crs = src.crs
        width, height = src.width, src.height
    
    # Update profile for multi-band output
    profile.update({
        'count': len(raster_files),
        'compress': '${params.compress_geotiff}',
        'tiled': True,
        'blockxsize': 256,
        'blockysize': 256
    })
    
    # Create geostack
    geostack_file = f'uganda_{variable}_geostack.tif'
    dates = []
    
    with rasterio.open(geostack_file, 'w', **profile) as dst:
        for i, raster_file in enumerate(raster_files, 1):
            # Extract date from filename
            date_str = raster_file.split('_daily_')[-1].replace('.tif', '')
            dates.append(date_str)
            
            # Read and write band
            with rasterio.open(raster_file) as src:
                data = src.read(1)
                dst.write(data, i)
                dst.set_band_description(i, f'{variable} - {date_str}')
    
    # Create geostack info
    geostack_info = {
        'variable': variable,
        'geostack_file': geostack_file,
        'total_bands': len(raster_files),
        'dates': dates,
        'temporal_coverage': {
            'start_date': dates[0] if dates else None,
            'end_date': dates[-1] if dates else None,
            'total_days': len(dates)
        },
        'spatial_info': {
            'width': width,
            'height': height,
            'crs': str(crs),
            'transform': list(transform)[:6],
            'bounds': {
                'left': transform[2],
                'bottom': transform[5] + transform[4] * height,
                'right': transform[2] + transform[0] * width,
                'top': transform[5]
            }
        },
        'creation_date': datetime.now().isoformat()
    }
    
    with open(f'uganda_{variable}_geostack_info.json', 'w') as f:
        json.dump(geostack_info, f, indent=2)
    
    print(f"✅ Created {variable} geostack: {len(dates)} time layers")
    """
}

/*
========================================================================================
    WORKFLOW
========================================================================================
*/

workflow {
    // Input CSV file - using absolute path
    csv_file = Channel.fromPath('/app/data/Uganda_Daily.csv')
        .ifEmpty { error "Uganda CSV file not found: /app/data/Uganda_Daily.csv" }
    
    // Prepare Uganda data
    UGANDA_DATA_PREPARATION(csv_file)
    
    // Create channel for target variables
    variables_ch = Channel.from(params.target_variables)
    
    // Daily spatial interpolation for each variable
    DAILY_SPATIAL_INTERPOLATION(
        UGANDA_DATA_PREPARATION.out.prepared_csv,
        variables_ch
    )
    
    // Create variable-specific geostacks
    if (params.create_geostack) {
        CREATE_VARIABLE_GEOSTACK(
            DAILY_SPATIAL_INTERPOLATION.out.daily_rasters.collect(),
            DAILY_SPATIAL_INTERPOLATION.out.interpolation_log,
            variables_ch
        )
    }
}

workflow.onComplete {
    println """
    
    🎉 UGANDA ENHANCED ANALYSIS WORKFLOW COMPLETED 🎉
    
    Status      : ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Work Dir    : ${workflow.workDir}
    Duration    : ${workflow.duration}
    
    📁 Output Directory: ${params.output_dir}
    📊 Variables Analyzed: ${params.target_variables.join(', ')}
    
    🌟 Enhanced Features Completed:
    🗺️  Daily Interpolation: ${params.enable_interpolation ? 'Yes' : 'No'}
    📊 GeoTIFF Creation: ${params.create_geotiff ? 'Yes' : 'No'}
    🗃️  Variable Geostacks: ${params.create_geostack ? 'Yes' : 'No'}
    📈 Spatial Distribution Analysis: ${params.create_spatial_distribution ? 'Yes' : 'No'}
    
    🔧 Processing Parameters:
    • Interpolation Method: ${params.interpolation_method}
    • Grid Resolution: ${params.grid_resolution}°
    • Max Days per Variable: ${params.max_days_per_variable}
    • Variogram Model: ${params.variogram_model}
    
    """.stripIndent()
}