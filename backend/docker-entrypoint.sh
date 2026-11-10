#!/bin/sh
set -e

echo "=================================================="
echo "  MePharma Enterprise Backend - Initializing"
echo "=================================================="

# Wait for PostgreSQL to become ready
echo "⏳ Waiting for PostgreSQL database connection..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_DATABASE" > /dev/null 2>&1; do
  echo "   PostgreSQL is unavailable - sleeping 1s"
  sleep 1
done
echo "✅ PostgreSQL database connected successfully."

# Run database migrations
echo "🚀 Applying database migrations..."
node ace migration:run --force || {
  echo "⚠️ Warning: Migration run encountered an issue or is already up to date."
}

# Seed default tenant and master catalog if empty
echo "🌱 Running system seeding..."
node ace db:seed || {
  echo "⚠️ Warning: Seeder execution finished or already seeded."
}

echo "✨ Starting AdonisJS v6 Server on port ${PORT:-3333}..."
exec node bin/server.js
