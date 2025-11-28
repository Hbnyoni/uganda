#!/usr/bin/env python3
"""
Enhanced Uganda Analysis with Daily Interpolation and GeoTIFF Creation
This script performs daily spatial interpolation for each variable and creates geostacks
"""

import pandas as pd
import numpy as np
from pykrige.ok import OrdinaryKriging
from scipy.spatial.distance import cdist
from scipy.interpolate import Rbf
import rasterio
from rasterio.transform import from_bounds
from rasterio.crs import CRS
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import json
import os
from datetime import datetime, timedelta
from glob import glob
import warnings
warnings.filterwarnings('ignore')

def run_enhanced_uganda_analysis():
    """Main function for enhanced Uganda spatial analysis"""
    
    print("🇺🇬 Starting Enhanced Uganda Spatial Analysis")
    print("=" * 60)
    
    # Configuration
    input_csv = '/app/data/Uganda_Daily.csv'
    output_dir = '/app/outputs/uganda_enhanced_analysis'
    target_variables = ['NDVI', 'pm25', 'no2', 'WRND', 'EH', 'EM', 'T2M', 'RH', 'LST', 'ET', 'TP', 'BLH']
    
    # Enhanced parameters
    max_days_per_variable = 30
    interpolation_method = 'kriging'
    grid_resolution = 0.005  # degrees
    variogram_model = 'spherical'
    buffer_percent = 0.2
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"📁 Output directory: {output_dir}")
    print(f"🔧 Grid resolution: {grid_resolution}° ({grid_resolution * 111:.1f}km)")
    print(f"📅 Max days per variable: {max_days_per_variable}")
    print(f"🧮 Interpolation method: {interpolation_method}")
    
    # Step 1: Load and prepare Uganda data
    print(f"\n📊 Step 1: Loading Uganda data...")
    try:
        df = pd.read_csv(input_csv)
        print(f"✅ Loaded {len(df)} total records")
        
        # Filter for Uganda
        uganda_df = df[df['country'] == 'Uganda'].copy()
        print(f"🇺🇬 Uganda records: {len(uganda_df)}")
        
        # Check available variables
        available_vars = [var for var in target_variables if var in uganda_df.columns]
        missing_vars = [var for var in target_variables if var not in uganda_df.columns]
        
        print(f"✅ Available variables: {available_vars}")
        if missing_vars:
            print(f"❌ Missing variables: {missing_vars}")
        
        # Clean data
        cols_to_keep = ['id', 'country', 'lat', 'lon', 'date'] + available_vars
        uganda_clean = uganda_df[cols_to_keep].copy()
        uganda_clean = uganda_clean.dropna(subset=['lat', 'lon'])
        
        # Convert date with flexible parsing
        uganda_clean['date'] = pd.to_datetime(uganda_clean['date'], dayfirst=True, errors='coerce')
        uganda_clean = uganda_clean.dropna(subset=['date'])  # Remove invalid dates
        
        print(f"📍 Cleaned dataset: {len(uganda_clean)} records")
        print(f"📅 Date range: {uganda_clean['date'].min()} to {uganda_clean['date'].max()}")
        print(f"🌍 Spatial extent: Lat {uganda_clean['lat'].min():.3f}-{uganda_clean['lat'].max():.3f}, Lon {uganda_clean['lon'].min():.3f}-{uganda_clean['lon'].max():.3f}")
        
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        return False
    
    # Step 2: Enhanced daily spatial interpolation for each variable
    print(f"\n🗺️ Step 2: Daily Spatial Interpolation...")
    
    results_summary = {
        'analysis_date': datetime.now().isoformat(),
        'total_records': len(uganda_clean),
        'variables_processed': [],
        'processing_results': {}
    }
    
    for var_idx, variable in enumerate(available_vars, 1):
        print(f"\n🔍 Processing variable {var_idx}/{len(available_vars)}: {variable}")
        
        # Get valid data for this variable
        valid_data = uganda_clean.dropna(subset=[variable]).copy()
        
        if len(valid_data) < 10:
            print(f"  ⚠️ Insufficient data for {variable}: {len(valid_data)} points")
            continue
        
        print(f"  📊 Valid data points: {len(valid_data)}")
        
        # Get spatial extent
        lat_min, lat_max = valid_data['lat'].min(), valid_data['lat'].max()
        lon_min, lon_max = valid_data['lon'].min(), valid_data['lon'].max()
        
        lat_buffer = (lat_max - lat_min) * buffer_percent
        lon_buffer = (lon_max - lon_min) * buffer_percent
        
        # Create interpolation grid
        n_lat = int((lat_max - lat_min + 2*lat_buffer) / grid_resolution) + 1
        n_lon = int((lon_max - lon_min + 2*lon_buffer) / grid_resolution) + 1
        
        # Limit grid size for performance
        n_lat = min(n_lat, 400)
        n_lon = min(n_lon, 400)
        
        grid_lat = np.linspace(lat_min - lat_buffer, lat_max + lat_buffer, n_lat)
        grid_lon = np.linspace(lon_min - lon_buffer, lon_max + lon_buffer, n_lon)
        grid_lon_2d, grid_lat_2d = np.meshgrid(grid_lon, grid_lat)
        
        print(f"  📏 Grid dimensions: {n_lat} x {n_lon} = {n_lat*n_lon:,} cells")
        
        # Get unique dates
        dates = sorted(valid_data['date'].dt.date.unique())
        selected_dates = dates[:max_days_per_variable]
        
        print(f"  📅 Processing {len(selected_dates)} days (out of {len(dates)} available)")
        
        # Initialize tracking
        interpolation_log = {
            'variable': variable,
            'successful_interpolations': 0,
            'failed_interpolations': 0,
            'daily_files': []
        }
        
        daily_raster_files = []
        
        # Define interpolation function
        def perform_interpolation(coords, values):
            try:
                if interpolation_method == 'kriging':
                    ok = OrdinaryKriging(
                        coords[:, 0], coords[:, 1], values,
                        variogram_model=variogram_model,
                        verbose=False,
                        enable_plotting=False
                    )
                    z, ss = ok.execute('grid', grid_lon, grid_lat)
                    return z
                elif interpolation_method == 'rbf':
                    rbf = Rbf(coords[:, 0], coords[:, 1], values, function='multiquadric')
                    z = rbf(grid_lon_2d, grid_lat_2d)
                    return z
                elif interpolation_method == 'idw':
                    # Inverse Distance Weighting
                    z = np.zeros_like(grid_lon_2d)
                    for i in range(len(grid_lat)):
                        for j in range(len(grid_lon)):
                            distances = cdist([(grid_lon[j], grid_lat[i])], coords)[0]
                            distances[distances == 0] = 1e-10
                            weights = 1 / (distances ** 2)
                            z[i, j] = np.sum(weights * values) / np.sum(weights)
                    return z
            except Exception as e:
                print(f"    ❌ Interpolation error: {e}")
                return None
        
        # Process each day
        for day_idx, date in enumerate(selected_dates):
            try:
                date_str = str(date)
                daily_data = valid_data[valid_data['date'].dt.date == date]
                
                if len(daily_data) < 5:
                    interpolation_log['failed_interpolations'] += 1
                    continue
                
                print(f"    📅 Day {day_idx+1}/{len(selected_dates)}: {date_str} ({len(daily_data)} points)")
                
                # Prepare coordinates and values
                coords = daily_data[['lon', 'lat']].values
                values = daily_data[variable].values
                
                # Perform interpolation
                z = perform_interpolation(coords, values)
                
                if z is None:
                    interpolation_log['failed_interpolations'] += 1
                    continue
                
                # Create GeoTIFF
                transform = from_bounds(
                    grid_lon.min(), grid_lat.min(),
                    grid_lon.max(), grid_lat.max(),
                    len(grid_lon), len(grid_lat)
                )
                
                output_file = os.path.join(output_dir, f'uganda_{variable}_daily_{date_str}.tif')
                
                with rasterio.open(
                    output_file, 'w',
                    driver='GTiff',
                    height=len(grid_lat), width=len(grid_lon),
                    count=1, dtype=np.float32,
                    crs=CRS.from_epsg(4326),
                    transform=transform,
                    compress='lzw'
                ) as dst:
                    dst.write(z.astype(np.float32), 1)
                    dst.set_band_description(1, f'Uganda {variable} - {date_str}')
                
                daily_raster_files.append(output_file)
                interpolation_log['successful_interpolations'] += 1
                interpolation_log['daily_files'].append(output_file)
                
            except Exception as e:
                print(f"    ❌ Error processing {date_str}: {e}")
                interpolation_log['failed_interpolations'] += 1
        
        success_rate = (interpolation_log['successful_interpolations'] / len(selected_dates) * 100) if len(selected_dates) > 0 else 0
        print(f"  ✅ Completed {variable}: {interpolation_log['successful_interpolations']}/{len(selected_dates)} days ({success_rate:.1f}% success)")
        
        # Step 3: Create variable geostack
        if daily_raster_files:
            print(f"  📚 Creating geostack for {variable}...")
            
            geostack_file = os.path.join(output_dir, f'uganda_{variable}_geostack.tif')
            
            # Read first raster for template
            with rasterio.open(daily_raster_files[0]) as src:
                profile = src.profile.copy()
                profile.update({
                    'count': len(daily_raster_files),
                    'compress': 'lzw'
                })
            
            # Create geostack
            with rasterio.open(geostack_file, 'w', **profile) as dst:
                for i, raster_file in enumerate(daily_raster_files, 1):
                    date_str = os.path.basename(raster_file).split('_daily_')[-1].replace('.tif', '')
                    
                    with rasterio.open(raster_file) as src:
                        data = src.read(1)
                        dst.write(data, i)
                        dst.set_band_description(i, f'{variable} - {date_str}')
            
            print(f"  ✅ Created geostack: {len(daily_raster_files)} bands")
        
        # Step 4: Create enhanced visualizations
        if daily_raster_files:
            print(f"  📈 Creating visualizations for {variable}...")
            
            # Read some sample rasters for visualization
            sample_files = daily_raster_files[:min(6, len(daily_raster_files))]
            
            fig, axes = plt.subplots(2, 3, figsize=(18, 12))
            axes = axes.flatten()
            
            # Calculate color scale
            all_data = []
            for raster_file in sample_files:
                with rasterio.open(raster_file) as src:
                    data = src.read(1)
                    valid_data = data[~np.isnan(data)]
                    if len(valid_data) > 0:
                        all_data.extend(valid_data)
            
            if all_data:
                vmin, vmax = np.percentile(all_data, [2, 98])
            else:
                vmin, vmax = 0, 1
            
            # Plot sample rasters
            for i, raster_file in enumerate(sample_files):
                date_str = os.path.basename(raster_file).split('_daily_')[-1].replace('.tif', '')
                
                with rasterio.open(raster_file) as src:
                    data = src.read(1)
                    extent = [src.bounds.left, src.bounds.right, src.bounds.bottom, src.bounds.top]
                
                im = axes[i].imshow(data, extent=extent, cmap='viridis', 
                                  vmin=vmin, vmax=vmax, aspect='auto')
                axes[i].set_title(f'{variable}\\n{date_str}', fontsize=11)
                axes[i].set_xlabel('Longitude (°E)')
                axes[i].set_ylabel('Latitude (°N)')
                
                # Add colorbar
                plt.colorbar(im, ax=axes[i], shrink=0.8)
            
            # Hide unused subplots
            for i in range(len(sample_files), 6):
                axes[i].set_visible(False)
            
            plt.suptitle(f'Uganda {variable} - Enhanced Spatial Distribution\\nDaily Interpolated Surfaces', 
                        fontsize=16, fontweight='bold')
            plt.tight_layout(rect=[0, 0.03, 1, 0.95])
            
            viz_file = os.path.join(output_dir, f'uganda_{variable}_enhanced_spatial_maps.png')
            plt.savefig(viz_file, dpi=200, bbox_inches='tight')
            plt.close()
            
            print(f"  ✅ Created visualization: {os.path.basename(viz_file)}")
        
        # Store results
        results_summary['variables_processed'].append(variable)
        results_summary['processing_results'][variable] = interpolation_log
    
    # Step 5: Create multi-variable geostack
    print(f"\n🌐 Step 3: Creating Multi-Variable Geostack...")
    
    all_daily_rasters = sorted(glob(os.path.join(output_dir, 'uganda_*_daily_*.tif')))
    
    if all_daily_rasters:
        print(f"📚 Found {len(all_daily_rasters)} daily raster files")
        
        # Read first raster for template
        with rasterio.open(all_daily_rasters[0]) as src:
            profile = src.profile.copy()
            profile.update({
                'count': len(all_daily_rasters),
                'compress': 'lzw'
            })
        
        multi_geostack_file = os.path.join(output_dir, 'uganda_all_variables_geostack.tif')
        
        with rasterio.open(multi_geostack_file, 'w', **profile) as dst:
            for i, raster_file in enumerate(all_daily_rasters, 1):
                filename = os.path.basename(raster_file)
                # Extract variable and date: uganda_{variable}_daily_{date}.tif
                parts = filename.replace('uganda_', '').replace('_daily_', '_').replace('.tif', '').split('_')
                if len(parts) >= 2:
                    variable = parts[0]
                    date = parts[1]
                    description = f'{variable} - {date}'
                else:
                    description = filename
                
                with rasterio.open(raster_file) as src:
                    data = src.read(1)
                    dst.write(data, i)
                    dst.set_band_description(i, description)
        
        print(f"✅ Created multi-variable geostack: {len(all_daily_rasters)} bands")
        
        # Create catalog
        catalog = {
            'multi_geostack_file': multi_geostack_file,
            'total_bands': len(all_daily_rasters),
            'variables': list(set([f.split('_')[1] for f in [os.path.basename(f) for f in all_daily_rasters]])),
            'band_catalog': [
                {
                    'band_number': i+1,
                    'filename': os.path.basename(f),
                    'variable': os.path.basename(f).split('_')[1],
                    'date': os.path.basename(f).split('_daily_')[1].replace('.tif', '')
                }
                for i, f in enumerate(all_daily_rasters)
            ],
            'creation_date': datetime.now().isoformat()
        }
        
        catalog_file = os.path.join(output_dir, 'uganda_multi_geostack_catalog.json')
        with open(catalog_file, 'w') as f:
            json.dump(catalog, f, indent=2)
        
        print(f"✅ Created geostack catalog: {os.path.basename(catalog_file)}")
    
    # Step 6: Final summary
    print(f"\n📊 Step 4: Analysis Summary...")
    
    # Save comprehensive results
    results_file = os.path.join(output_dir, 'uganda_enhanced_analysis_results.json')
    with open(results_file, 'w') as f:
        json.dump(results_summary, f, indent=2)
    
    # Summary statistics
    total_successful = sum([r['successful_interpolations'] for r in results_summary['processing_results'].values()])
    total_failed = sum([r['failed_interpolations'] for r in results_summary['processing_results'].values()])
    total_geotiffs = len(glob(os.path.join(output_dir, '*.tif')))
    
    print(f"\n🎉 Enhanced Analysis Complete!")
    print(f"📁 Output directory: {output_dir}")
    print(f"📊 Variables processed: {len(results_summary['variables_processed'])}")
    print(f"✅ Successful interpolations: {total_successful}")
    print(f"❌ Failed interpolations: {total_failed}")
    print(f"🗺️ GeoTIFF files created: {total_geotiffs}")
    print(f"📚 Variable geostacks: {len(results_summary['variables_processed'])}")
    print(f"🌐 Multi-variable geostack: 1")
    
    return True

if __name__ == "__main__":
    success = run_enhanced_uganda_analysis()
    if success:
        print("\n✅ Enhanced Uganda analysis completed successfully! 🇺🇬✨")
    else:
        print("\n❌ Enhanced Uganda analysis failed!")