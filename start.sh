#!/bin/bash
exec gunicorn --bind 0.0.0.0:${PORT:-8080} --workers 2 --timeout 200 app:app