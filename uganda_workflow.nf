#!/usr/bin/env nextflow

/*
========================================================================================
    CHEAQI UGANDA-FOCUSED SPATIAL INTERPOLATION WORKFLOW
========================================================================================
    Focus: Uganda data only, specific variables, with maps and animations
========================================================================================
*/

nextflow.enable.dsl = 2

// Uganda-specific parameters
params.input_csv = '/app/data/Uganda_Daily.csv'
params.country_filter = 'Uganda'
params.output_dir = '/app/outputs/uganda_analysis'
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

// Interpolation parameters
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

// Visualization parameters
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
    print("Loading Uganda Daily data...")
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
    
    print(f"Available variables: {available_vars}")
    if missing_vars:
        print(f"Missing variables: {missing_vars}")
    
    # Filter for available columns only - use correct column names
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
    
    print(f"Prepared Uganda dataset: {len(uganda_clean)} records")
    print(f"Variables ready for analysis: {available_vars}")
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
    
    # Convert date column to datetime
    df['date'] = pd.to_datetime(df['date'], errors='coerce')
    
    # Filter valid data for this variable
    valid_data = df.dropna(subset=[variable, 'lat', 'lon']).copy()
    
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
    print(f"📋 Creating geostack for {variable}")
    
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

process CREATE_MULTI_VARIABLE_GEOSTACK {
    tag "Multi-Variable Geostack"
    
    input:
    path all_daily_rasters
    path all_logs
    
    output:
    path "uganda_all_variables_geostack.tif", emit: multi_geostack
    path "uganda_multi_geostack_catalog.json", emit: catalog
    
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
    import re
    import warnings
    warnings.filterwarnings('ignore')
    
    print("🌍 Creating multi-variable geostack")
    
    # Find all daily rasters
    all_rasters = sorted(glob('uganda_*_daily_*.tif'))
    
    if not all_rasters:
        print("No daily rasters found")
        with open('uganda_multi_geostack_catalog.json', 'w') as f:
            json.dump({'error': 'No daily rasters found'}, f)
        exit(0)
    
    print(f"Found {len(all_rasters)} daily raster files")
    
    # Parse raster information
    raster_info = []
    for raster_file in all_rasters:
        # Extract variable and date from filename: uganda_{variable}_daily_{date}.tif
        match = re.match(r'uganda_(.+)_daily_(.+)\.tif', raster_file)
        if match:
            variable, date = match.groups()
            raster_info.append({
                'file': raster_file,
                'variable': variable,
                'date': date,
                'sort_key': f'{date}_{variable}'
            })
    
    # Sort by date then variable
    raster_info.sort(key=lambda x: x['sort_key'])
    
    if not raster_info:
        print("No valid raster files found")
        exit(0)
    
    # Read first raster for template
    with rasterio.open(raster_info[0]['file']) as src:
        profile = src.profile.copy()
        profile.update({
            'count': len(raster_info),
            'compress': '${params.compress_geotiff}',
            'tiled': True,
            'blockxsize': 256,
            'blockysize': 256
        })
    
    # Create multi-variable geostack
    multi_geostack_file = 'uganda_all_variables_geostack.tif'
    
    with rasterio.open(multi_geostack_file, 'w', **profile) as dst:
        for i, info in enumerate(raster_info, 1):
            with rasterio.open(info['file']) as src:
                data = src.read(1)
                dst.write(data, i)
                dst.set_band_description(i, f"{info['variable']} - {info['date']}")
    
    # Create catalog
    catalog = {
        'multi_geostack_file': multi_geostack_file,
        'total_bands': len(raster_info),
        'variables': list(set([info['variable'] for info in raster_info])),
        'date_range': {
            'start': min([info['date'] for info in raster_info]),
            'end': max([info['date'] for info in raster_info])
        },
        'band_catalog': [
            {
                'band_number': i+1,
                'variable': info['variable'],
                'date': info['date'],
                'description': f"{info['variable']} - {info['date']}"
            }
            for i, info in enumerate(raster_info)
        ],
        'creation_date': datetime.now().isoformat()
    }
    
    with open('uganda_multi_geostack_catalog.json', 'w') as f:
        json.dump(catalog, f, indent=2)
    
    print(f"✅ Created multi-variable geostack: {len(raster_info)} bands across {len(set([i['variable'] for i in raster_info]))} variables")
    """
}

process CREATE_ENHANCED_SPATIAL_MAPS {
    tag "Enhanced Spatial Maps: \${variable}"
    
    input:
    path variable_geostack
    path geostack_info
    path spatial_stats
    each variable
    
    output:
    path "uganda_\${variable}_spatial_distribution.png", emit: spatial_maps
    path "uganda_\${variable}_temporal_overview.png", emit: temporal_maps
    path "uganda_\${variable}_statistics_summary.png", emit: stats_plots
    path "uganda_\${variable}_mapping_report.json", emit: mapping_report
    
    when:
    params.create_spatial_distribution
    
    script:
    """
    #!/usr/bin/env python3
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    import matplotlib.patches as patches
    import rasterio
    import numpy as np
    from glob import glob
    import json
    from datetime import datetime
    import seaborn as sns
    import warnings
    warnings.filterwarnings('ignore')
    
    # Set style
    plt.style.use('default')
    sns.set_palette('viridis')
    
    variable = '${variable}'
    geostack_file = f'uganda_{variable}_geostack.tif'
    
    # Load geostack info and stats
    try:
        with open(f'uganda_{variable}_geostack_info.json') as f:
            geostack_info = json.load(f)
        with open(f'uganda_{variable}_spatial_stats.json') as f:
            spatial_stats = json.load(f)
    except FileNotFoundError:
        print(f"Missing files for {variable}")
        # Create empty outputs
        for output_file in ['spatial_distribution.png', 'temporal_overview.png', 'statistics_summary.png']:
            plt.figure(figsize=(8, 6))
            plt.text(0.5, 0.5, f'No data available for {variable}', 
                    ha='center', va='center', fontsize=16)
            plt.title(f'Uganda {variable} - No Data')
            plt.axis('off')
            plt.savefig(f'uganda_{variable}_{output_file}', dpi=150, bbox_inches='tight')
            plt.close()
        
        with open(f'uganda_{variable}_mapping_report.json', 'w') as f:
            json.dump({'variable': variable, 'maps_created': 0, 'error': 'No data'}, f)
        exit(0)
    
    # Check if geostack exists
    try:
        with rasterio.open(geostack_file) as src:
            n_bands = src.count
            bounds = src.bounds
            transform = src.transform
            print(f"Processing {variable} geostack: {n_bands} bands")
    except:
        print(f"Geostack not found for {variable}")
        exit(0)
    
    # 1. CREATE SPATIAL DISTRIBUTION OVERVIEW
    fig, axes = plt.subplots(2, 3, figsize=(18, 12))
    axes = axes.flatten()
    
    # Sample bands to show spatial distribution over time
    band_indices = np.linspace(1, n_bands, 6, dtype=int) if n_bands >= 6 else list(range(1, n_bands+1))
    
    with rasterio.open(geostack_file) as src:
        # Calculate overall statistics for color scaling
        all_data = []
        for band_idx in band_indices[:6]:
            if band_idx <= n_bands:
                data = src.read(band_idx)
                valid_data = data[~np.isnan(data)]
                if len(valid_data) > 0:
                    all_data.extend(valid_data)
        
        if all_data:
            vmin, vmax = np.percentile(all_data, [2, 98])
        else:
            vmin, vmax = 0, 1
    
    # Plot sample rasters
    plot_indices = np.linspace(0, len(raster_files)-1, n_plots, dtype=int)
    
    for i, idx in enumerate(plot_indices):
        raster_file = raster_files[idx]
        
        # Extract date from filename
        date_str = raster_file.split('_')[-1].replace('.tif', '')
        
        # Read raster
        with rasterio.open(raster_file) as src:
            data = src.read(1)
            extent = [src.bounds.left, src.bounds.right, src.bounds.bottom, src.bounds.top]
        
        # Plot
        im = axes[i].imshow(data, extent=extent, cmap='${params.map_style}', aspect='auto')
        axes[i].set_title(f'{variable}\\n{date_str}', fontsize=10)
        axes[i].set_xlabel('Longitude')
        axes[i].set_ylabel('Latitude')
        
        # Add colorbar
        plt.colorbar(im, ax=axes[i], shrink=0.6)
    
        # Hide unused subplots
        for i in range(len(band_indices), 6):
            axes[i].set_visible(False)
    
    plt.suptitle(f'Uganda {variable} - Spatial Distribution Analysis\nTemporal Samples from Interpolated Surface', 
                fontsize=16, fontweight='bold')
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.savefig(f'uganda_{variable}_spatial_distribution.png', dpi=200, bbox_inches='tight', 
               facecolor='white', edgecolor='none')
    plt.close()
    
    # 2. CREATE TEMPORAL OVERVIEW
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
    
    # Extract temporal statistics
    dates = [datetime.strptime(d, '%Y-%m-%d') for d in geostack_info['dates']]
    daily_means = []
    daily_stds = []
    daily_coverage = []
    
    with rasterio.open(geostack_file) as src:
        for band_idx in range(1, n_bands + 1):
            data = src.read(band_idx)
            valid_data = data[~np.isnan(data)]
            
            if len(valid_data) > 0:
                daily_means.append(np.mean(valid_data))
                daily_stds.append(np.std(valid_data))
                daily_coverage.append(len(valid_data) / data.size * 100)
            else:
                daily_means.append(np.nan)
                daily_stds.append(np.nan)
                daily_coverage.append(0)
    
    # Time series plot
    ax1.plot(dates, daily_means, 'b-', linewidth=2, marker='o', markersize=3, label='Daily Mean')
    ax1.fill_between(dates, 
                    np.array(daily_means) - np.array(daily_stds),
                    np.array(daily_means) + np.array(daily_stds),
                    alpha=0.3, color='blue', label='±1 Std Dev')
    ax1.set_title(f'{variable} - Temporal Variation', fontsize=14, fontweight='bold')
    ax1.set_xlabel('Date', fontsize=12)
    ax1.set_ylabel(f'{variable} Value', fontsize=12)
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # Coverage plot
    ax2.bar(dates, daily_coverage, width=1, color='green', alpha=0.7, edgecolor='darkgreen')
    ax2.set_title('Spatial Coverage (%)', fontsize=14, fontweight='bold')
    ax2.set_xlabel('Date', fontsize=12)
    ax2.set_ylabel('Coverage (%)', fontsize=12)
    ax2.grid(True, alpha=0.3)
    
    # Monthly aggregation
    monthly_data = {}
    for i, date in enumerate(dates):
        month_key = date.strftime('%Y-%m')
        if month_key not in monthly_data:
            monthly_data[month_key] = []
        if not np.isnan(daily_means[i]):
            monthly_data[month_key].append(daily_means[i])
    
    months = sorted(monthly_data.keys())
    monthly_means = [np.mean(monthly_data[m]) if monthly_data[m] else np.nan for m in months]
    monthly_dates = [datetime.strptime(m, '%Y-%m') for m in months]
    
    ax3.plot(monthly_dates, monthly_means, 'r-', linewidth=3, marker='s', markersize=6)
    ax3.set_title(f'{variable} - Monthly Averages', fontsize=14, fontweight='bold')
    ax3.set_xlabel('Month', fontsize=12)
    ax3.set_ylabel(f'{variable} Value', fontsize=12)
    ax3.grid(True, alpha=0.3)
    
    # Distribution histogram
    all_valid_values = [v for v in daily_means if not np.isnan(v)]
    if all_valid_values:
        ax4.hist(all_valid_values, bins=20, color='purple', alpha=0.7, edgecolor='black')
        ax4.axvline(np.mean(all_valid_values), color='red', linestyle='--', linewidth=2, 
                   label=f'Mean: {np.mean(all_valid_values):.3f}')
        ax4.axvline(np.median(all_valid_values), color='orange', linestyle='--', linewidth=2,
                   label=f'Median: {np.median(all_valid_values):.3f}')
    ax4.set_title(f'{variable} - Value Distribution', fontsize=14, fontweight='bold')
    ax4.set_xlabel(f'{variable} Value', fontsize=12)
    ax4.set_ylabel('Frequency', fontsize=12)
    ax4.legend()
    ax4.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'uganda_{variable}_temporal_overview.png', dpi=200, bbox_inches='tight',
               facecolor='white', edgecolor='none')
    plt.close()
    
    # 3. CREATE STATISTICS SUMMARY
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 10))
    
    # Overall statistics from spatial_stats
    overall_stats = spatial_stats.get('overall_stats', {})
    value_dist = overall_stats.get('value_distribution', {})
    
    # Statistics bar chart
    stats_names = ['Min', 'Q25', 'Median', 'Mean', 'Q75', 'Max']
    stats_values = [
        value_dist.get('min', 0),
        value_dist.get('percentiles', {}).get('25', 0),
        value_dist.get('percentiles', {}).get('50', 0),
        value_dist.get('mean', 0),
        value_dist.get('percentiles', {}).get('75', 0),
        value_dist.get('max', 0)
    ]
    
    bars = ax1.bar(stats_names, stats_values, color=['blue', 'lightblue', 'green', 'red', 'lightblue', 'blue'])
    ax1.set_title(f'{variable} - Statistical Summary', fontsize=14, fontweight='bold')
    ax1.set_ylabel(f'{variable} Value', fontsize=12)
    ax1.grid(True, alpha=0.3)
    
    # Add value labels on bars
    for bar, value in zip(bars, stats_values):
        if not np.isnan(value):
            ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(stats_values)*0.01,
                    f'{value:.3f}', ha='center', va='bottom', fontsize=10)
    
    # Interpolation success rate
    daily_stats = spatial_stats.get('daily_stats', {})
    success_dates = [d for d, stats in daily_stats.items() if stats.get('spatial_coverage', 0) > 50]
    success_rate = len(success_dates) / len(daily_stats) * 100 if daily_stats else 0
    
    # Coverage analysis
    coverages = [stats.get('spatial_coverage', 0) for stats in daily_stats.values()]
    if coverages:
        ax2.hist(coverages, bins=15, color='green', alpha=0.7, edgecolor='black')
        ax2.axvline(np.mean(coverages), color='red', linestyle='--', linewidth=2,
                   label=f'Mean: {np.mean(coverages):.1f}%')
    ax2.set_title('Spatial Coverage Distribution', fontsize=14, fontweight='bold')
    ax2.set_xlabel('Coverage (%)', fontsize=12)
    ax2.set_ylabel('Frequency', fontsize=12)
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # Data availability calendar-like plot
    if dates and daily_coverage:
        ax3.scatter(range(len(dates)), daily_coverage, c=daily_coverage, 
                   cmap='RdYlGn', s=50, alpha=0.8, edgecolors='black', linewidth=0.5)
        ax3.set_title('Daily Data Availability', fontsize=14, fontweight='bold')
        ax3.set_xlabel('Day Index', fontsize=12)
        ax3.set_ylabel('Coverage (%)', fontsize=12)
        ax3.grid(True, alpha=0.3)
        
        # Add colorbar
        cbar = plt.colorbar(ax3.collections[0], ax=ax3)
        cbar.set_label('Coverage (%)', fontsize=10)
    
    # Summary text
    summary_text = f"""
    Variable: {variable}
    
    Data Summary:
    • Total Days Processed: {len(daily_stats)}
    • Successful Interpolations: {len(success_dates)}
    • Success Rate: {success_rate:.1f}%
    • Average Coverage: {np.mean(coverages):.1f}% ± {np.std(coverages):.1f}%
    
    Value Statistics:
    • Mean: {value_dist.get('mean', 0):.3f} ± {value_dist.get('std', 0):.3f}
    • Range: {value_dist.get('min', 0):.3f} - {value_dist.get('max', 0):.3f}
    • Data Points: {overall_stats.get('total_data_points', 0):,}
    
    Spatial Info:
    • Grid Resolution: {grid_resolution:.4f}°
    • Grid Size: {geostack_info['spatial_info']['width']} x {geostack_info['spatial_info']['height']}
    • Total Grid Cells: {geostack_info['spatial_info']['width'] * geostack_info['spatial_info']['height']:,}
    """
    
    ax4.text(0.05, 0.95, summary_text, transform=ax4.transAxes, fontsize=11,
            verticalalignment='top', bbox=dict(boxstyle='round', facecolor='lightgray', alpha=0.8))
    ax4.set_xlim(0, 1)
    ax4.set_ylim(0, 1)
    ax4.axis('off')
    
    plt.tight_layout()
    plt.savefig(f'uganda_{variable}_statistics_summary.png', dpi=200, bbox_inches='tight',
               facecolor='white', edgecolor='none')
    plt.close()
    
    # Create comprehensive mapping report
    mapping_report = {
        'variable': variable,
        'geostack_info': geostack_info,
        'processing_summary': {
            'total_days_available': len(geostack_info['dates']),
            'successful_interpolations': len(success_dates),
            'success_rate_percent': success_rate,
            'average_spatial_coverage': float(np.mean(coverages)) if coverages else 0,
            'coverage_std': float(np.std(coverages)) if coverages else 0
        },
        'statistical_summary': spatial_stats.get('overall_stats', {}),
        'temporal_analysis': {
            'daily_means_range': [float(min(daily_means)), float(max(daily_means))] if daily_means else [0, 0],
            'temporal_variability': float(np.std(daily_means)) if daily_means else 0,
            'seasonal_patterns': 'Analysis available in temporal overview plot'
        },
        'output_files': {
            'spatial_distribution': f'uganda_{variable}_spatial_distribution.png',
            'temporal_overview': f'uganda_{variable}_temporal_overview.png',
            'statistics_summary': f'uganda_{variable}_statistics_summary.png',
            'geostack': f'uganda_{variable}_geostack.tif'
        },
        'creation_date': datetime.now().isoformat()
    }
    
    with open(f'uganda_{variable}_mapping_report.json', 'w') as f:
        json.dump(mapping_report, f, indent=2, default=str)
    
    print(f"✅ Created comprehensive visualization suite for {variable}")
    print(f"  🗺️ Spatial distribution: {len(band_indices)} time samples")
    print(f"  📈 Temporal overview: {len(dates)} days analyzed")
    print(f"  📊 Statistics: {success_rate:.1f}% success rate")
    """
}

process CREATE_TIME_SERIES_ANIMATION {
    tag "Animation: \${variable}"
    
    input:
    path raster_files
    each variable
    
    output:
    path "uganda_\${variable}_animation.gif", emit: animations
    path "uganda_\${variable}_timeseries.png", emit: timeseries_plot
    
    when:
    params.create_animations
    
    script:
    """
    #!/usr/bin/env python3
    import matplotlib.pyplot as plt
    import matplotlib.animation as animation
    import rasterio
    import numpy as np
    from glob import glob
    import json
    from datetime import datetime
    import warnings
    warnings.filterwarnings('ignore')
    
    variable = '${variable}'
    raster_pattern = f'uganda_{variable}_*.tif'
    raster_files = sorted(glob(raster_pattern))
    
    if len(raster_files) < 2:
        print(f"Insufficient raster files for animation: {len(raster_files)}")
        # Create placeholder
        fig, ax = plt.subplots(figsize=(10, 8))
        ax.text(0.5, 0.5, f'Insufficient data for {variable} animation\\n({len(raster_files)} files)', 
                ha='center', va='center', fontsize=16)
        ax.set_title(f'Uganda {variable} - Animation Not Available')
        ax.axis('off')
        plt.savefig(f'uganda_{variable}_animation.gif', dpi=100, bbox_inches='tight')
        plt.close()
        
        # Create empty time series
        fig, ax = plt.subplots(figsize=(12, 6))
        ax.text(0.5, 0.5, f'No time series data for {variable}', ha='center', va='center', fontsize=16)
        ax.set_title(f'Uganda {variable} - Time Series')
        plt.savefig(f'uganda_{variable}_timeseries.png', dpi=150, bbox_inches='tight')
        plt.close()
        exit(0)
    
    print(f"Creating animation for {variable} from {len(raster_files)} rasters")
    
    # Read all rasters and compute stats
    dates = []
    mean_values = []
    min_values = []
    max_values = []
    all_data = []
    extents = []
    
    for raster_file in raster_files[:20]:  # Limit to first 20 for performance
        # Extract date
        date_str = raster_file.split('_')[-1].replace('.tif', '')
        dates.append(datetime.strptime(date_str, '%Y-%m-%d'))
        
        # Read raster
        with rasterio.open(raster_file) as src:
            data = src.read(1)
            extent = [src.bounds.left, src.bounds.right, src.bounds.bottom, src.bounds.top]
            
        all_data.append(data)
        extents.append(extent)
        
        # Compute stats (excluding NaN/nodata)
        valid_data = data[~np.isnan(data)]
        if len(valid_data) > 0:
            mean_values.append(np.mean(valid_data))
            min_values.append(np.min(valid_data))
            max_values.append(np.max(valid_data))
        else:
            mean_values.append(np.nan)
            min_values.append(np.nan)
            max_values.append(np.nan)
    
    # Determine color scale
    all_valid = np.concatenate([d[~np.isnan(d)] for d in all_data if np.any(~np.isnan(d))])
    if len(all_valid) > 0:
        vmin, vmax = np.percentile(all_valid, [5, 95])
    else:
        vmin, vmax = 0, 1
    
    # Create animation
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
    
    # Map subplot
    im = ax1.imshow(all_data[0], extent=extents[0], cmap='${params.map_style}', 
                    vmin=vmin, vmax=vmax, aspect='auto')
    ax1.set_title(f'{variable} - {dates[0].strftime("%Y-%m-%d")}')
    ax1.set_xlabel('Longitude')
    ax1.set_ylabel('Latitude')
    plt.colorbar(im, ax=ax1, shrink=0.6)
    
    # Time series subplot
    ax2.plot(dates, mean_values, 'b-', label='Mean', linewidth=2)
    ax2.fill_between(dates, min_values, max_values, alpha=0.3, color='blue', label='Min-Max Range')
    ax2.set_title(f'Uganda {variable} - Time Series Statistics')
    ax2.set_xlabel('Date')
    ax2.set_ylabel(f'{variable} Value')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # Add current time indicator
    time_line = ax2.axvline(dates[0], color='red', linestyle='--', linewidth=2, label='Current Time')
    ax2.legend()
    
    def animate(frame):
        # Update map
        im.set_array(all_data[frame])
        ax1.set_title(f'{variable} - {dates[frame].strftime("%Y-%m-%d")}')
        
        # Update time indicator
        time_line.set_xdata([dates[frame], dates[frame]])
        
        return [im, time_line]
    
    # Create animation
    anim = animation.FuncAnimation(fig, animate, frames=len(all_data), 
                                 interval=1000/${params.animation_fps}, blit=False, repeat=True)
    
    # Save animation
    anim.save(f'uganda_{variable}_animation.gif', writer='pillow', fps=${params.animation_fps}, dpi=100)
    plt.close()
    
    # Create separate time series plot
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.plot(dates, mean_values, 'b-', linewidth=2, marker='o', markersize=4, label='Daily Mean')
    ax.fill_between(dates, min_values, max_values, alpha=0.3, color='blue', label='Daily Range')
    
    ax.set_title(f'Uganda {variable} - Time Series Analysis', fontsize=14)
    ax.set_xlabel('Date', fontsize=12)
    ax.set_ylabel(f'{variable} Value', fontsize=12)
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Format x-axis
    ax.tick_params(axis='x', rotation=45)
    
    plt.tight_layout()
    plt.savefig(f'uganda_{variable}_timeseries.png', dpi=150, bbox_inches='tight')
    plt.close()
    
    print(f"Created {variable} animation and time series: {len(all_data)} frames")
    """
}

process GENERATE_SUMMARY_REPORT {
    tag "Summary Report"
    
    input:
    path stats_json
    path validation_jsons
    path map_summaries
    
    output:
    path "uganda_analysis_report.html", emit: html_report
    path "uganda_analysis_summary.json", emit: json_summary
    
    script:
    """
    #!/usr/bin/env python3
    import json
    from datetime import datetime
    from glob import glob
    
    # Load statistics
    with open('${stats_json}') as f:
        stats = json.load(f)
    
    # Load validation results
    validation_files = glob('*_validation.json')
    validations = {}
    for vf in validation_files:
        with open(vf) as f:
            data = json.load(f)
            validations[data['variable']] = data
    
    # Load map summaries
    map_files = glob('*_map_summary.json')
    map_summaries = {}
    for mf in map_files:
        with open(mf) as f:
            data = json.load(f)
            map_summaries[data['variable']] = data
    
    # Generate summary
    summary = {
        'analysis_date': datetime.now().isoformat(),
        'dataset_info': stats,
        'processing_results': {
            'variables_processed': list(validations.keys()),
            'total_interpolations': sum(v.get('successful_interpolations', 0) for v in validations.values()),
            'failed_interpolations': sum(v.get('failed_interpolations', 0) for v in validations.values())
        },
        'visualization_results': {
            'maps_created': sum(m.get('maps_created', 0) for m in map_summaries.values()),
            'animations_created': len(glob('uganda_*_animation.gif'))
        },
        'variable_details': validations,
        'map_details': map_summaries
    }
    
    # Save JSON summary
    with open('uganda_analysis_summary.json', 'w') as f:
        json.dump(summary, f, indent=2)
    
    # Generate HTML report
    html_content = f'''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Uganda Spatial Analysis Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            .header {{ background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
            .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
            .variable-box {{ background: #f8f9fa; padding: 10px; margin: 10px 0; border-radius: 3px; }}
            .success {{ color: #28a745; }}
            .error {{ color: #dc3545; }}
            table {{ width: 100%; border-collapse: collapse; }}
            th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
            th {{ background-color: #f2f2f2; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🇺🇬 Uganda Spatial Interpolation Analysis Report</h1>
            <p>Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        </div>
        
        <div class="section">
            <h2>📊 Dataset Overview</h2>
            <table>
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Total Records</td><td>{stats.get('total_records', 'N/A'):,}</td></tr>
                <tr><td>Date Range</td><td>{stats.get('date_range', {}).get('start', 'N/A')} to {stats.get('date_range', {}).get('end', 'N/A')}</td></tr>
                <tr><td>Latitude Range</td><td>{stats.get('spatial_extent', {}).get('lat_min', 'N/A'):.3f} to {stats.get('spatial_extent', {}).get('lat_max', 'N/A'):.3f}</td></tr>
                <tr><td>Longitude Range</td><td>{stats.get('spatial_extent', {}).get('lon_min', 'N/A'):.3f} to {stats.get('spatial_extent', {}).get('lon_max', 'N/A'):.3f}</td></tr>
            </table>
        </div>
        
        <div class="section">
            <h2>🗺️ Processing Results</h2>
            <table>
                <tr><th>Variable</th><th>Successful</th><th>Failed</th><th>Success Rate</th></tr>
    '''
    
    for var, val_data in validations.items():
        success = val_data.get('successful_interpolations', 0)
        failed = val_data.get('failed_interpolations', 0)
        total = success + failed
        success_rate = (success / total * 100) if total > 0 else 0
        
        html_content += f'''
                <tr>
                    <td>{var}</td>
                    <td class="success">{success}</td>
                    <td class="error">{failed}</td>
                    <td>{"%.1f" % success_rate}%</td>
                </tr>
        '''
    
    html_content += f'''
            </table>
        </div>
        
        <div class="section">
            <h2>📈 Variable Statistics</h2>
    '''
    
    for var, var_stats in stats.get('variables', {}).items():
        if var_stats.get('count', 0) > 0:
            html_content += f'''
            <div class="variable-box">
                <h4>{var}</h4>
                <p><strong>Data Points:</strong> {var_stats.get('count', 'N/A'):,}</p>
                <p><strong>Range:</strong> {var_stats.get('min', 'N/A'):.3f} to {var_stats.get('max', 'N/A'):.3f}</p>
                <p><strong>Mean ± Std:</strong> {var_stats.get('mean', 'N/A'):.3f} ± {var_stats.get('std', 'N/A'):.3f}</p>
            </div>
            '''
    
    html_content += f'''
        </div>
        
        <div class="section">
            <h2>🎯 Summary</h2>
            <ul>
                <li><strong>Variables Processed:</strong> {len(validations)} variables</li>
                <li><strong>Total Interpolations:</strong> {summary['processing_results']['total_interpolations']:,}</li>
                <li><strong>Maps Created:</strong> {summary['visualization_results']['maps_created']}</li>
                <li><strong>Animations Created:</strong> {summary['visualization_results']['animations_created']}</li>
            </ul>
        </div>
    </body>
    </html>
    '''
    
    with open('uganda_analysis_report.html', 'w') as f:
        f.write(html_content)
    
    print("Generated Uganda analysis summary report")
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
        
        // Create multi-variable geostack
        CREATE_MULTI_VARIABLE_GEOSTACK(
            DAILY_SPATIAL_INTERPOLATION.out.daily_rasters.collect(),
            DAILY_SPATIAL_INTERPOLATION.out.interpolation_log.collect()
        )
    }
    
    // Create enhanced spatial distribution maps
    if (params.create_spatial_distribution) {
        CREATE_ENHANCED_SPATIAL_MAPS(
            CREATE_VARIABLE_GEOSTACK.out.variable_geostack,
            CREATE_VARIABLE_GEOSTACK.out.geostack_info,
            DAILY_SPATIAL_INTERPOLATION.out.spatial_stats,
            variables_ch
        )
    }
    
    // Create animations for each variable
    if (params.create_animations) {
        CREATE_TIME_SERIES_ANIMATION(
            SPATIAL_INTERPOLATION_UGANDA.out.interpolated_rasters.collect(),
            variables_ch
        )
    }
    
    // Generate comprehensive summary report
    GENERATE_SUMMARY_REPORT(
        UGANDA_DATA_PREPARATION.out.stats,
        DAILY_SPATIAL_INTERPOLATION.out.interpolation_log.collect(),
        params.create_spatial_distribution ? CREATE_ENHANCED_SPATIAL_MAPS.out.mapping_report.collect() : Channel.empty()
    )
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
    🌐 Multi-Variable Stack: ${params.create_geostack ? 'Yes' : 'No'}
    📈 Spatial Distribution Analysis: ${params.create_spatial_distribution ? 'Yes' : 'No'}
    🎬 Animations: ${params.create_animations ? 'Yes' : 'No'}
    
    🔧 Processing Parameters:
    • Interpolation Method: ${params.interpolation_method}
    • Grid Resolution: ${params.grid_resolution}°
    • Max Days per Variable: ${params.max_days_per_variable}
    • Variogram Model: ${params.variogram_model}
    
    """.stripIndent()
}