#!/usr/bin/env python3
"""
CHEAQI Real-time Workflow Monitor
Provides real-time monitoring and status updates for Docker-based workflows
"""

import time
import json
import subprocess
import psutil
import os
from pathlib import Path
from datetime import datetime
from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import threading
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = 'cheaqi-monitor-secret'
socketio = SocketIO(app, cors_allowed_origins="*")

# Configuration
MONITOR_CONFIG = {
    'data_dir': '/app/data',
    'outputs_dir': '/app/outputs', 
    'scripts_dir': '/app/scripts',
    'work_dir': '/tmp/nextflow_work',
    'monitor_interval': 5,  # seconds
    'log_retention_hours': 24
}

# Global state
workflow_status = {}
system_metrics = {}
active_processes = {}

class WorkflowMonitor:
    """Monitor Nextflow workflows and system resources"""
    
    def __init__(self):
        self.running = False
        self.workflows = {}
        
    def start_monitoring(self):
        """Start the monitoring thread"""
        self.running = True
        monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        monitor_thread.start()
        logger.info("Workflow monitor started")
        
    def stop_monitoring(self):
        """Stop monitoring"""
        self.running = False
        logger.info("Workflow monitor stopped")
        
    def _monitor_loop(self):
        """Main monitoring loop"""
        while self.running:
            try:
                self._update_system_metrics()
                self._check_workflows()
                self._update_file_status()
                
                # Broadcast updates via WebSocket
                socketio.emit('status_update', {
                    'timestamp': datetime.now().isoformat(),
                    'system': system_metrics,
                    'workflows': workflow_status,
                    'processes': active_processes
                })
                
                time.sleep(MONITOR_CONFIG['monitor_interval'])
                
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(10)
    
    def _update_system_metrics(self):
        """Update system resource metrics"""
        global system_metrics
        
        try:
            # CPU and Memory
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            # Docker container stats
            docker_stats = self._get_docker_stats()
            
            system_metrics = {
                'timestamp': datetime.now().isoformat(),
                'cpu': {
                    'percent': cpu_percent,
                    'count': psutil.cpu_count()
                },
                'memory': {
                    'total': memory.total,
                    'used': memory.used,
                    'percent': memory.percent,
                    'available': memory.available
                },
                'disk': {
                    'total': disk.total,
                    'used': disk.used,
                    'percent': (disk.used / disk.total) * 100,
                    'free': disk.free
                },
                'docker': docker_stats,
                'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else [0, 0, 0]
            }
            
        except Exception as e:
            logger.error(f"Error updating system metrics: {e}")
            
    def _get_docker_stats(self):
        """Get Docker container statistics"""
        try:
            result = subprocess.run(['docker', 'stats', '--no-stream', '--format', 
                                   'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}'],
                                  capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                containers = []
                
                for line in lines[1:]:  # Skip header
                    parts = line.split('\t')
                    if len(parts) >= 6:
                        containers.append({
                            'name': parts[0],
                            'cpu': parts[1],
                            'memory_usage': parts[2],
                            'memory_percent': parts[3],
                            'network': parts[4],
                            'block_io': parts[5]
                        })
                
                return containers
                
        except Exception as e:
            logger.error(f"Error getting Docker stats: {e}")
            
        return []
    
    def _check_workflows(self):
        """Check status of active Nextflow workflows"""
        global workflow_status
        
        # Check for Nextflow processes
        nextflow_processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cmdline', 'create_time', 'cpu_percent', 'memory_percent']):
            try:
                if 'nextflow' in proc.info['name'].lower() or any('nextflow' in str(cmd).lower() for cmd in proc.info['cmdline']):
                    nextflow_processes.append({
                        'pid': proc.info['pid'],
                        'cmdline': ' '.join(proc.info['cmdline'][:3]) + '...' if len(proc.info['cmdline']) > 3 else ' '.join(proc.info['cmdline']),
                        'started': datetime.fromtimestamp(proc.info['create_time']).isoformat(),
                        'cpu_percent': proc.info['cpu_percent'],
                        'memory_percent': proc.info['memory_percent'],
                        'status': 'running'
                    })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        # Update workflow status
        workflow_status['nextflow_processes'] = nextflow_processes
        workflow_status['active_count'] = len(nextflow_processes)
        
        # Check for work directories
        work_dirs = []
        if Path(MONITOR_CONFIG['work_dir']).exists():
            for work_path in Path(MONITOR_CONFIG['work_dir']).glob('*'):
                if work_path.is_dir():
                    work_dirs.append({
                        'name': work_path.name,
                        'path': str(work_path),
                        'created': datetime.fromtimestamp(work_path.stat().st_ctime).isoformat(),
                        'size': self._get_dir_size(work_path)
                    })
        
        workflow_status['work_directories'] = work_dirs
        
    def _get_dir_size(self, path):
        """Get directory size in bytes"""
        try:
            total = 0
            for entry in os.scandir(path):
                if entry.is_file(follow_symlinks=False):
                    total += entry.stat().st_size
                elif entry.is_dir(follow_symlinks=False):
                    total += self._get_dir_size(entry.path)
            return total
        except (OSError, PermissionError):
            return 0
    
    def _update_file_status(self):
        """Monitor input/output file changes"""
        global active_processes
        
        file_stats = {}
        
        # Check data directory
        if Path(MONITOR_CONFIG['data_dir']).exists():
            csv_files = list(Path(MONITOR_CONFIG['data_dir']).glob('*.csv'))
            file_stats['input_files'] = {
                'count': len(csv_files),
                'total_size': sum(f.stat().st_size for f in csv_files if f.exists()),
                'files': [{'name': f.name, 'size': f.stat().st_size, 'modified': datetime.fromtimestamp(f.stat().st_mtime).isoformat()} for f in csv_files[:5]]
            }
        
        # Check outputs directory
        if Path(MONITOR_CONFIG['outputs_dir']).exists():
            output_files = list(Path(MONITOR_CONFIG['outputs_dir']).rglob('*'))
            output_files = [f for f in output_files if f.is_file()]
            
            file_stats['output_files'] = {
                'count': len(output_files),
                'total_size': sum(f.stat().st_size for f in output_files if f.exists()),
                'recent_files': [
                    {
                        'name': f.name, 
                        'path': str(f.relative_to(Path(MONITOR_CONFIG['outputs_dir']))),
                        'size': f.stat().st_size, 
                        'modified': datetime.fromtimestamp(f.stat().st_mtime).isoformat()
                    } 
                    for f in sorted(output_files, key=lambda x: x.stat().st_mtime, reverse=True)[:10]
                ]
            }
        
        active_processes['file_stats'] = file_stats

# Initialize monitor
monitor = WorkflowMonitor()

@app.route('/')
def dashboard():
    """Main monitoring dashboard"""
    return render_template('monitor.html')

@app.route('/api/status')
def get_status():
    """Get current system and workflow status"""
    return jsonify({
        'system': system_metrics,
        'workflows': workflow_status,
        'processes': active_processes,
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/workflows')
def get_workflows():
    """Get detailed workflow information"""
    workflows = []
    
    # Check for recent workflow reports
    if Path(MONITOR_CONFIG['outputs_dir']).exists():
        report_files = list(Path(MONITOR_CONFIG['outputs_dir']).glob('*_report.json'))
        
        for report_file in sorted(report_files, key=lambda x: x.stat().st_mtime, reverse=True)[:10]:
            try:
                with open(report_file) as f:
                    report_data = json.load(f)
                
                workflows.append({
                    'name': report_file.stem,
                    'file': report_file.name,
                    'completed': datetime.fromtimestamp(report_file.stat().st_mtime).isoformat(),
                    'dataset': report_data.get('dataset', 'Unknown'),
                    'variables': len(report_data.get('results', {})),
                    'status': 'completed'
                })
            except Exception as e:
                logger.error(f"Error reading report {report_file}: {e}")
    
    return jsonify({
        'workflows': workflows,
        'active_count': workflow_status.get('active_count', 0)
    })

@app.route('/api/system')
def get_system_info():
    """Get detailed system information"""
    return jsonify({
        'system': system_metrics,
        'config': MONITOR_CONFIG,
        'uptime': time.time() - psutil.boot_time()
    })

@app.route('/api/logs')
def get_logs():
    """Get recent workflow logs"""
    logs = []
    
    # Check for log files in work directories
    if Path(MONITOR_CONFIG['work_dir']).exists():
        log_files = list(Path(MONITOR_CONFIG['work_dir']).rglob('*.log'))
        
        for log_file in sorted(log_files, key=lambda x: x.stat().st_mtime, reverse=True)[:5]:
            try:
                with open(log_file) as f:
                    content = f.read()[-1000:]  # Last 1000 characters
                
                logs.append({
                    'file': str(log_file.relative_to(Path(MONITOR_CONFIG['work_dir']))),
                    'modified': datetime.fromtimestamp(log_file.stat().st_mtime).isoformat(),
                    'size': log_file.stat().st_size,
                    'content': content
                })
            except Exception as e:
                logger.error(f"Error reading log {log_file}: {e}")
    
    return jsonify({'logs': logs})

@socketio.on('connect')
def on_connect():
    """Handle client connection"""
    logger.info("Client connected to monitor")
    emit('status_update', {
        'system': system_metrics,
        'workflows': workflow_status,
        'processes': active_processes,
        'timestamp': datetime.now().isoformat()
    })

@socketio.on('disconnect')
def on_disconnect():
    """Handle client disconnection"""
    logger.info("Client disconnected from monitor")

@socketio.on('request_update')
def on_request_update():
    """Handle manual update request"""
    emit('status_update', {
        'system': system_metrics,
        'workflows': workflow_status,
        'processes': active_processes,
        'timestamp': datetime.now().isoformat()
    })

if __name__ == '__main__':
    # Start monitoring
    monitor.start_monitoring()
    
    # Run Flask app
    try:
        socketio.run(app, host='0.0.0.0', port=8890, debug=False)
    except KeyboardInterrupt:
        logger.info("Shutting down monitor...")
        monitor.stop_monitoring()