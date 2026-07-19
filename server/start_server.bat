@echo off
cd /d "%~dp0"

echo [1/2] Cloudflare Tunnel 시작...
start "Cloudflare Tunnel" cloudflared tunnel run

echo [2/2] FastAPI 서버 시작...
python -m uvicorn main:app --host 0.0.0.0 --port 8000
