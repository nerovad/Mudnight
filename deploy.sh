#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Pulling latest code..."
git pull

echo "Installing dependencies..."
npm install
(cd backend && bundle config set --local without "development test" && bundle install)

echo "Building frontend..."
npm run build --workspace=frontend

echo "Running database migrations..."
(cd backend && RAILS_ENV=production bin/rails db:migrate)

echo "Restarting backend..."
if ! command -v pm2 &> /dev/null; then
  echo "PM2 not found, installing globally..."
  npm install -g pm2
fi

pm2 startOrRestart ecosystem.config.js --env production
pm2 save

echo "Deploy complete!"
