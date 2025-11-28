# Enhanced Uganda Analysis Runner (PowerShell)
Write-Host "🚀 Starting Enhanced Uganda Spatial Analysis" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

# Copy enhanced workflow to container
Write-Host "📁 Copying enhanced workflow files to container..." -ForegroundColor Yellow
docker cp uganda_enhanced_workflow.nf cheaqi-spatial-web:/app/
docker cp uganda.config cheaqi-spatial-web:/app/uganda_enhanced.config

# Run the enhanced workflow
Write-Host "🔄 Running enhanced spatial interpolation workflow..." -ForegroundColor Yellow
docker exec -it cheaqi-spatial-web bash -c @"
    cd /app && 
    source /opt/conda/etc/profile.d/conda.sh && 
    conda activate cheaqi && 
    nextflow run uganda_enhanced_workflow.nf -c uganda_enhanced.config -profile docker --output_dir /app/outputs/uganda_enhanced_analysis
"@

if ($LASTEXITCODE -eq 0) {
    # Check results
    Write-Host "📊 Checking results..." -ForegroundColor Yellow
    docker exec cheaqi-spatial-web bash -c @"
        cd /app/outputs/uganda_enhanced_analysis && 
        echo 'Generated files:' && 
        find . -name '*.tif' -o -name '*.json' | head -20 && 
        echo '...' &&
        echo 'Total GeoTIFF files:' && 
        find . -name '*.tif' | wc -l &&
        echo 'Total JSON files:' &&
        find . -name '*.json' | wc -l
"@
    
    Write-Host "✅ Enhanced analysis completed!" -ForegroundColor Green
    Write-Host "📁 Results are in container: /app/outputs/uganda_enhanced_analysis" -ForegroundColor Cyan
    Write-Host "🔽 To copy results locally, run:" -ForegroundColor Cyan
    Write-Host "   docker cp cheaqi-spatial-web:/app/outputs/uganda_enhanced_analysis/. ./uganda_enhanced_results/" -ForegroundColor White
} else {
    Write-Host "❌ Analysis failed. Check the logs above for errors." -ForegroundColor Red
}