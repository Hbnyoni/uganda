# CHEAQI Simple CSV Processor
FROM condaforge/mambaforge:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gdal-bin \
    gdal-data \
    libgdal-dev \
    libproj-dev \
    libgeos-dev \
    libspatialindex-dev \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create conda environment file
COPY environment.yml /app/environment.yml

# Create conda environment
RUN mamba env create -f environment.yml && \
    mamba clean -afy && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.pyc' -delete

# Create directories and copy files
RUN mkdir -p /app/data /app/outputs /app/notebooks /app/templates
COPY app.py /app/
COPY templates/ /app/templates/
COPY scripts/ /app/scripts/ 
COPY data/ /app/data/ 

# Install Nextflow with proper Java environment
RUN /bin/bash -c "source /opt/conda/etc/profile.d/conda.sh && \
    conda activate cheaqi && \
    curl -s https://get.nextflow.io | bash && \
    mv nextflow /usr/local/bin/ && \
    chmod +x /usr/local/bin/nextflow"

# Copy Nextflow workflow
COPY main.nf /app/
COPY nextflow.config /app/

# Set proper permissions
RUN chmod -R 755 /app && \
    chown -R root:root /app

# Expose web server port
EXPOSE 8888

# Create startup script for Flask web interface with Nextflow support
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'set -e' >> /app/start.sh && \
    echo 'echo "Starting CHEAQI Spatial Interpolation Web Interface with Nextflow..."' >> /app/start.sh && \
    echo 'source /opt/conda/etc/profile.d/conda.sh' >> /app/start.sh && \
    echo 'conda activate cheaqi' >> /app/start.sh && \
    echo 'export JAVA_HOME=/opt/conda/envs/cheaqi' >> /app/start.sh && \
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /app/start.sh && \
    echo 'echo "Java version: $(java -version 2>&1 | head -n1)"' >> /app/start.sh && \
    echo 'echo "Nextflow version: $(nextflow -version 2>/dev/null || echo 'Nextflow not ready')"' >> /app/start.sh && \
    echo 'echo "Flask server starting on port 8888..."' >> /app/start.sh && \
    echo 'cd /app && python app.py' >> /app/start.sh && \
    chmod +x /app/start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8888/ || exit 1

# Default command
CMD ["/app/start.sh"]