#!/usr/bin/env python3
"""
CHEAQI System Test Script
Tests all major functionality to ensure the system is working correctly
"""

import requests
import json
import time

BASE_URL = "http://localhost:8888"

def test_api_endpoint(endpoint, method="GET", data=None, expected_status=200):
    """Test an API endpoint and return the result"""
    try:
        if method == "GET":
            response = requests.get(f"{BASE_URL}{endpoint}", timeout=10)
        elif method == "POST":
            response = requests.post(f"{BASE_URL}{endpoint}", 
                                   json=data, 
                                   headers={'Content-Type': 'application/json'}, 
                                   timeout=30)
        
        print(f"✅ {endpoint} - Status: {response.status_code}")
        
        if response.status_code == expected_status:
            try:
                return response.json()
            except:
                return {"raw_content": response.text}
        else:
            print(f"❌ Expected {expected_status}, got {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ {endpoint} - Error: {str(e)}")
        return None

def main():
    """Run comprehensive system tests"""
    print("🚀 CHEAQI System Test Suite")
    print("=" * 50)
    
    # Test 1: Basic connectivity
    print("\n📡 Testing Basic Connectivity...")
    home_response = test_api_endpoint("/")
    if home_response is None:
        print("❌ Cannot connect to CHEAQI system")
        return
    
    # Test 2: Files API
    print("\n📁 Testing File Management...")
    files_data = test_api_endpoint("/api/files")
    if files_data and files_data.get('success'):
        print(f"   Files available: {len(files_data.get('files', []))}")
        available_files = files_data.get('files', [])
        if available_files:
            test_file = available_files[0]
            print(f"   Using test file: {test_file}")
        else:
            print("❌ No CSV files available for testing")
            return
    else:
        print("❌ Files API failed")
        return
    
    # Test 3: Variable Selection
    print("\n🔍 Testing Variable Selection...")
    var_data = test_api_endpoint(f"/api/variable_selection/{test_file}")
    if var_data:
        variables = var_data.get('variables', [])
        coordinates = var_data.get('coordinates', {})
        print(f"   Variables found: {len(variables)}")
        print(f"   Latitude candidates: {len(coordinates.get('latitude', []))}")
        print(f"   Longitude candidates: {len(coordinates.get('longitude', []))}")
        
        if len(variables) == 0:
            print("❌ No variables detected - this indicates a problem")
        elif len(variables) > 5:
            print("✅ Good number of variables for interpolation")
        
        # Select test variables for interpolation
        test_variables = [v['name'] for v in variables[:3]] if variables else []
        lat_col = coordinates.get('latitude', [None])[0]
        lon_col = coordinates.get('longitude', [None])[0]
        
    else:
        print("❌ Variable selection failed")
        return
    
    # Test 4: CSV Info API
    print("\n📊 Testing CSV Analysis...")
    csv_info = test_api_endpoint(f"/api/csv_info/{test_file}")
    if csv_info:
        print(f"   Total columns: {len(csv_info.get('columns', []))}")
        print(f"   Data shape: {csv_info.get('shape', 'Unknown')}")
    
    # Test 5: Variable Explorer (Advanced)
    print("\n🔍 Testing Advanced Variable Explorer...")
    explorer_data = test_api_endpoint(f"/api/get_all_variables/{test_file}")
    if explorer_data:
        print(f"   Advanced analysis completed")
    
    # Test 6: Interpolation (if we have valid inputs)
    if test_variables and lat_col and lon_col:
        print("\n⚡ Testing Spatial Interpolation...")
        interpolation_data = {
            "filename": test_file,
            "variables": test_variables,
            "lat_column": lat_col,
            "lon_column": lon_col,
            "method": "kriging"
        }
        
        interp_result = test_api_endpoint("/api/run_interpolation", 
                                        method="POST", 
                                        data=interpolation_data,
                                        expected_status=200)
        
        if interp_result:
            if interp_result.get('success'):
                print("✅ Interpolation completed successfully")
                processed = interp_result.get('variables_successful', 0)
                total = interp_result.get('variables_requested', 0)
                print(f"   Variables processed: {processed}/{total}")
            else:
                print(f"❌ Interpolation failed: {interp_result.get('error', 'Unknown error')}")
        
    else:
        print("\n⚠️ Skipping interpolation test (insufficient data)")
        print(f"   Variables: {len(test_variables)}, Lat: {lat_col}, Lon: {lon_col}")
    
    # Test Summary
    print("\n" + "=" * 50)
    print("📋 TEST SUMMARY")
    print("   If you see mostly ✅ marks above, the system is working!")
    print("   If you see ❌ marks, there are issues that need fixing.")
    print("=" * 50)

if __name__ == "__main__":
    main()