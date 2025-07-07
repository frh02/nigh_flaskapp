#!/bin/bash
cd /home/site/wwwroot
mkdir -p static/files
gunicorn --bind 0.0.0.0:$PORT --workers 1 --timeout 0 --preload app:app