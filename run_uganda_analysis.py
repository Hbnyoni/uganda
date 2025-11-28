#!/usr/bin/env python3
"""
Direct Uganda Analysis Script - Alternative to Nextflow
This script runs the Uganda spatial analysis without Nextflow dependencies
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import json
import os
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

def run_uganda_analysis():
    """Main analysis function for Uganda data"""
    
    print("🇺🇬 Starting Uganda Spatial Analysis")
    print("="*50)
    
    # Configuration
    input_csv = '/app/data/Uganda_Daily.csv'
    output_dir = '/app/outputs/uganda_analysis'
    target_variables = ['NDVI', 'pm25', 'no2', 'WRND', 'EH', 'EM', 'T2M', 'RH', 'LST', 'ET', 'TP', 'BLH']
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Step 1: Load and prepare data
    print("📊 Loading Uganda data...")
    try:
        df = pd.read_csv(input_csv)
        print(f"Loaded {len(df)} records from Uganda_Daily.csv")
        
        # Filter for Uganda
        uganda_df = df[df['country'] == 'Uganda'].copy()
        print(f"Uganda records: {len(uganda_df)}")
        
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
        
        # Convert date
        uganda_clean['date'] = pd.to_datetime(uganda_clean['date'], dayfirst=True, errors='coerce')
        
        print(f"📍 Cleaned dataset: {len(uganda_clean)} records")
        print(f"📅 Date range: {uganda_clean['date'].min()} to {uganda_clean['date'].max()}")
        print(f"🌍 Spatial extent: Lat {uganda_clean['lat'].min():.3f} to {uganda_clean['lat'].max():.3f}, Lon {uganda_clean['lon'].min():.3f} to {uganda_clean['lon'].max():.3f}")
        
    except Exception as e:
        print(f"❌ Error loading data: {e}")
        return False
    
    # Step 2: Basic Analysis for each variable
    print("\n📈 Analyzing variables...")
    
    results = {
        'analysis_date': datetime.now().isoformat(),
        'total_records': len(uganda_clean),
        'variables_analyzed': available_vars,
        'results': {}
    }
    
    for var in available_vars:
        print(f"\n🔍 Analyzing {var}...")
        
        # Get valid data for this variable
        valid_data = uganda_clean.dropna(subset=[var])
        
        if len(valid_data) < 10:
            print(f"  ⚠️ Insufficient data for {var}: {len(valid_data)} points")
            continue
        
        # Basic statistics
        stats = {
            'data_points': len(valid_data),
            'date_range': {
                'start': valid_data['date'].min().isoformat(),
                'end': valid_data['date'].max().isoformat()
            },
            'spatial_coverage': {
                'lat_range': [float(valid_data['lat'].min()), float(valid_data['lat'].max())],
                'lon_range': [float(valid_data['lon'].min()), float(valid_data['lon'].max())],
            },
            'value_stats': {
                'mean': float(valid_data[var].mean()),
                'std': float(valid_data[var].std()),
                'min': float(valid_data[var].min()),
                'max': float(valid_data[var].max()),
                'median': float(valid_data[var].median())
            }
        }
        
        # Time series analysis
        daily_stats = valid_data.groupby(valid_data['date'].dt.date)[var].agg(['mean', 'std', 'count']).reset_index()
        daily_stats['date'] = pd.to_datetime(daily_stats['date'])
        
        # Create time series plot
        plt.figure(figsize=(12, 6))
        plt.plot(daily_stats['date'], daily_stats['mean'], 'b-', linewidth=2, label='Daily Mean')
        plt.fill_between(daily_stats['date'], 
                        daily_stats['mean'] - daily_stats['std'],
                        daily_stats['mean'] + daily_stats['std'],
                        alpha=0.3, color='blue', label='±1 Std Dev')
        
        plt.title(f'Uganda {var} - Time Series Analysis', fontsize=14)
        plt.xlabel('Date', fontsize=12)
        plt.ylabel(f'{var} Value', fontsize=12)
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.xticks(rotation=45)
        plt.tight_layout()
        
        # Save plot
        plot_file = os.path.join(output_dir, f'uganda_{var}_timeseries.png')
        plt.savefig(plot_file, dpi=150, bbox_inches='tight')
        plt.close()
        
        # Spatial distribution plot
        plt.figure(figsize=(10, 8))
        scatter = plt.scatter(valid_data['lon'], valid_data['lat'], 
                            c=valid_data[var], cmap='viridis', 
                            s=20, alpha=0.6)
        plt.colorbar(scatter, label=f'{var} Value')
        plt.title(f'Uganda {var} - Spatial Distribution', fontsize=14)
        plt.xlabel('Longitude', fontsize=12)
        plt.ylabel('Latitude', fontsize=12)
        plt.grid(True, alpha=0.3)
        
        # Save spatial plot
        spatial_file = os.path.join(output_dir, f'uganda_{var}_spatial.png')
        plt.savefig(spatial_file, dpi=150, bbox_inches='tight')
        plt.close()
        
        stats['plots_created'] = [
            f'uganda_{var}_timeseries.png',
            f'uganda_{var}_spatial.png'
        ]
        
        results['results'][var] = stats
        print(f"  ✅ {var}: {len(valid_data)} points, Range: {stats['value_stats']['min']:.3f} - {stats['value_stats']['max']:.3f}")
    
    # Step 3: Summary Report
    print(f"\n📋 Generating summary report...")
    
    # Create HTML summary
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Uganda Analysis Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }}
            .header {{ background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }}
            .section {{ margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }}
            .variable-box {{ background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 5px; }}
            .stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 10px; }}
            .stat-item {{ background: white; padding: 10px; border: 1px solid #ddd; border-radius: 3px; }}
            table {{ width: 100%; border-collapse: collapse; margin: 10px 0; }}
            th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
            th {{ background-color: #f2f2f2; }}
            .success {{ color: #28a745; font-weight: bold; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🇺🇬 Uganda Environmental Data Analysis Report</h1>
            <p>Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        </div>
        
        <div class="section">
            <h2>📊 Dataset Summary</h2>
            <div class="stats">
                <div class="stat-item">
                    <strong>Total Records:</strong><br>
                    {results['total_records']:,}
                </div>
                <div class="stat-item">
                    <strong>Variables Analyzed:</strong><br>
                    {len(results['variables_analyzed'])}
                </div>
                <div class="stat-item">
                    <strong>Date Range:</strong><br>
                    {uganda_clean['date'].min().strftime('%Y-%m-%d')} to {uganda_clean['date'].max().strftime('%Y-%m-%d')}
                </div>
                <div class="stat-item">
                    <strong>Spatial Coverage:</strong><br>
                    Lat: {uganda_clean['lat'].min():.3f} to {uganda_clean['lat'].max():.3f}<br>
                    Lon: {uganda_clean['lon'].min():.3f} to {uganda_clean['lon'].max():.3f}
                </div>
            </div>
        </div>
    """
    
    # Add variable sections
    for var, var_stats in results['results'].items():
        html_content += f"""
        <div class="section">
            <div class="variable-box">
                <h3>{var}</h3>
                <div class="stats">
                    <div class="stat-item">
                        <strong>Data Points:</strong><br>
                        <span class="success">{var_stats['data_points']:,}</span>
                    </div>
                    <div class="stat-item">
                        <strong>Mean ± Std:</strong><br>
                        {var_stats['value_stats']['mean']:.3f} ± {var_stats['value_stats']['std']:.3f}
                    </div>
                    <div class="stat-item">
                        <strong>Range:</strong><br>
                        {var_stats['value_stats']['min']:.3f} to {var_stats['value_stats']['max']:.3f}
                    </div>
                    <div class="stat-item">
                        <strong>Median:</strong><br>
                        {var_stats['value_stats']['median']:.3f}
                    </div>
                </div>
                <p><strong>Visualizations:</strong> Time series plot, Spatial distribution map</p>
            </div>
        </div>
        """
    
    html_content += """
        <div class="section">
            <h2>🎯 Analysis Complete</h2>
            <p>All available variables have been processed. Check the output directory for:</p>
            <ul>
                <li>📈 Time series plots for each variable</li>
                <li>🗺️ Spatial distribution maps</li>
                <li>📊 Statistical summaries</li>
                <li>📋 This comprehensive report</li>
            </ul>
        </div>
    </body>
    </html>
    """
    
    # Save HTML report
    report_file = os.path.join(output_dir, 'uganda_analysis_report.html')
    with open(report_file, 'w') as f:
        f.write(html_content)
    
    # Save JSON results
    json_file = os.path.join(output_dir, 'uganda_analysis_results.json')
    with open(json_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n🎉 Analysis Complete!")
    print(f"📁 Output directory: {output_dir}")
    print(f"📊 Variables analyzed: {len(results['variables_analyzed'])}")
    print(f"📈 Plots created: {len(results['variables_analyzed']) * 2}")
    print(f"📋 Reports: HTML + JSON")
    
    return True

if __name__ == "__main__":
    success = run_uganda_analysis()
    if success:
        print("\n✅ Uganda analysis completed successfully!")
    else:
        print("\n❌ Uganda analysis failed!")