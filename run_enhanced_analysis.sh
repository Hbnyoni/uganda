#!/bin/bash

# Enhanced Uganda Analysis Runner
echo "🚀 Starting Enhanced Uganda Spatial Analysis"
echo "=============================================="

# Copy enhanced workflow to container
echo "📁 Copying enhanced workflow files to container..."
docker cp uganda_enhanced_workflow.nf cheaqi-spatial-web:/app/
docker cp uganda.config cheaqi-spatial-web:/app/uganda_enhanced.config

# Run the enhanced workflow
echo "🔄 Running enhanced spatial interpolation workflow..."
docker exec -it cheaqi-spatial-web bash -c "
    cd /app && 
    source /opt/conda/etc/profile.d/conda.sh && 
    conda activate cheaqi && 
    nextflow run uganda_enhanced_workflow.nf -c uganda_enhanced.config -profile docker --output_dir /app/outputs/uganda_enhanced_analysis
"

# Check results
echo "📊 Checking results..."
docker exec cheaqi-spatial-web bash -c "
    cd /app/outputs/uganda_enhanced_analysis && 
    echo 'Generated files:' && 
    find . -name '*.tif' -o -name '*.json' | head -20 && 
    echo '...' &&
    echo 'Total GeoTIFF files:' && 
    find . -name '*.tif' | wc -l &&
    echo 'Total JSON files:' &&
    find . -name '*.json' | wc -l
"

echo "✅ Enhanced analysis completed!"
echo "📁 Results are in container: /app/outputs/uganda_enhanced_analysis"
echo "🔽 To copy results locally, run:"
echo "   docker cp cheaqi-spatial-web:/app/outputs/uganda_enhanced_analysis/. ./uganda_enhanced_results/"