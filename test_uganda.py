#!/usr/bin/env python3
import pandas as pd
import numpy as np
import json

print("=== UGANDA ANALYSIS TEST ===")

# Load Uganda data
df = pd.read_csv('/app/data/Uganda_Daily.csv')
print(f"Total records: {len(df)}")

# Filter for Uganda
uganda_df = df[df['country'] == 'Uganda'].copy()
print(f"Uganda records: {len(uganda_df)}")

# Target variables
target_vars = ['NDVI', 'pm25', 'no2', 'WRND', 'EH', 'EM', 'T2M', 'RH', 'LST', 'ET', 'TP', 'BLH']
print(f"Target variables: {target_vars}")

# Check available columns
print(f"Available columns: {list(uganda_df.columns)}")
available_vars = [var for var in target_vars if var in uganda_df.columns]
print(f"Available target variables: {available_vars}")

# Basic statistics
for var in available_vars[:3]:  # Just check first 3 variables
    valid_data = uganda_df[var].dropna()
    print(f"{var}: {len(valid_data)} valid points, range: {valid_data.min():.3f} to {valid_data.max():.3f}")

print("=== TEST COMPLETE ===")