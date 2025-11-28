#!/usr/bin/env python3
"""
CHEAQI Batch Processing Script

This script allows running the CHEAQI spatial interpolation workflow
in batch mode without the interactive Jupyter interface.
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional, Sequence

import pandas as pd

# Import the core processing functions from the notebook
# Note: This requires the notebook functions to be extracted into a separate module


def main():
    parser = argparse.ArgumentParser(
        description="CHEAQI Spatial Interpolation Batch Processor"
    )
    
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Path to input CSV file"
    )
    
    parser.add_argument(
        "--output", "-o", 
        required=True,
        help="Output directory for results"
    )
    
    parser.add_argument(
        "--config", "-c",
        help="Configuration file (JSON format)"
    )
    
    parser.add_argument(
        "--aoi",
        help="Area of Interest shapefile"
    )
    
    parser.add_argument(
        "--lon-col",
        default="longitude",
        help="Longitude column name (default: longitude)"
    )
    
    parser.add_argument(
        "--lat-col", 
        default="latitude",
        help="Latitude column name (default: latitude)"
    )
    
    parser.add_argument(
        "--date-col",
        default="date",
        help="Date column name (default: date)"
    )
    
    parser.add_argument(
        "--variables",
        nargs="+",
        help="Variable column names to interpolate"
    )
    
    parser.add_argument(
        "--method",
        choices=["gdal_grid", "python_idw_kdtree", "pykrige_ok"],
        default="gdal_grid",
        help="Interpolation method (default: gdal_grid)"
    )
    
    parser.add_argument(
        "--cell-size",
        type=float,
        default=1000.0,
        help="Grid cell size in meters (default: 1000)"
    )
    
    parser.add_argument(
        "--power",
        type=float,
        default=2.0,
        help="IDW power parameter (default: 2.0)"
    )
    
    parser.add_argument(
        "--jobs",
        type=int,
        default=4,
        help="Number of parallel jobs (default: 4)"
    )
    
    args = parser.parse_args()
    
    # Validate inputs
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"ERROR: Input file not found: {input_path}")
        sys.exit(1)
    
    output_path = Path(args.output)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Load configuration if provided
    config = {}
    if args.config:
        config_path = Path(args.config)
        if config_path.exists():
            with open(config_path) as f:
                config = json.load(f)
        else:
            print(f"WARNING: Config file not found: {config_path}")
    
    # Determine variables to process
    if args.variables:
        variables = args.variables
    elif "variables" in config:
        variables = config["variables"]
    else:
        # Try to infer from CSV
        try:
            df_sample = pd.read_csv(input_path, nrows=5)
            excluded = {args.lon_col, args.lat_col, args.date_col}
            variables = [col for col in df_sample.columns if col not in excluded]
            print(f"INFO: Auto-detected variables: {variables}")
        except Exception as e:
            print(f"ERROR: Could not determine variables: {e}")
            sys.exit(1)
    
    if not variables:
        print("ERROR: No variables specified for interpolation")
        sys.exit(1)
    
    print("=" * 60)
    print("CHEAQI Spatial Interpolation Batch Process")
    print("=" * 60)
    print(f"Input file: {input_path}")
    print(f"Output directory: {output_path}")
    print(f"Variables: {variables}")
    print(f"Method: {args.method}")
    print(f"Cell size: {args.cell_size}m")
    print(f"Power: {args.power}")
    print(f"Jobs: {args.jobs}")
    print("=" * 60)
    
    try:
        # Import and run the processing workflow
        # Note: This would import from the extracted notebook functions
        from cheaqi_core import process_workflow
        
        process_workflow(
            csv_path=str(input_path),
            aoi_path=args.aoi,
            lon_col=args.lon_col,
            lat_col=args.lat_col,
            date_col=args.date_col,
            variable_cols=variables,
            method=args.method,
            cell_size=args.cell_size,
            power=args.power,
            jobs=args.jobs,
            output_folder=str(output_path),
        )
        
        print("=" * 60)
        print("Processing completed successfully!")
        print(f"Results saved to: {output_path}")
        print("=" * 60)
        
    except ImportError:
        print("ERROR: CHEAQI core functions not available.")
        print("Please ensure the notebook functions are extracted to cheaqi_core.py")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR during processing: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()