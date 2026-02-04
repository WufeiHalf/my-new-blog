#!/usr/bin/env bash
set -e
cd /opt/blog

echo "[deploy] pulling latest code..."
git pull --ff-only

echo "[deploy] generating site..."
npx hexo clean
npx hexo generate

echo "[deploy] done."
