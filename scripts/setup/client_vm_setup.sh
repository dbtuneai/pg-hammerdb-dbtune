#!/bin/bash
# Client VM Setup Script for HammerDB Benchmarking
# This script sets up a VM for running HammerDB TPROC-C benchmarks

set -e  # Stop script on first error

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Update system
echo "Updating system packages..."
apt update
apt -y upgrade

# Install prerequisites
echo "Installing prerequisites..."
apt -y install curl unzip build-essential libssl-dev libffi-dev python3-pip netcat-openbsd python3-psycopg2

# Install Python 3.8
echo "Installing Python 3.8..."
add-apt-repository -y ppa:deadsnakes/ppa
apt update
apt -y install python3.8 python3.8-venv python3.8-dev python3.8-distutils

# Install PostgreSQL client
apt -y install postgresql-client

# Get PostgreSQL server IP address only - using pre-configured credentials
read -p "Enter the PostgreSQL server IP address: " PG_HOST

# Use pre-configured credentials
PG_USER="admin"
PG_PASSWORD="password"

# Download and extract HammerDB
echo "Downloading HammerDB..."
wget https://github.com/TPC-Council/HammerDB/releases/download/v4.12/HammerDB-4.12-Linux.tar.gz
tar -xzf HammerDB-4.12-Linux.tar.gz
rm HammerDB-4.12-Linux.tar.gz

# Check if HammerDB extracted properly
if [ ! -d "HammerDB-4.12" ]; then
    echo "Failed to extract HammerDB properly"
    exit 1
fi

# Check outbound connectivity to PostgreSQL server
echo "Checking if the PostgreSQL port is accessible..."
if nc -zv "$PG_HOST" 5432; then
    echo "Successfully connected to PostgreSQL server at $PG_HOST:5432"
else
    echo "WARNING: Could not connect to PostgreSQL server at $PG_HOST:5432"
    echo "Please check network settings, firewall rules, and PostgreSQL configuration."
    exit 1
fi

# Test database connection with admin user
echo "Testing PostgreSQL connection..."
python3 -c "import psycopg2; conn = psycopg2.connect(host=\"$PG_HOST\", user=\"$PG_USER\", password=\"$PG_PASSWORD\", dbname=\"postgres\"); print(\"Connection successful\"); conn.close()" || {
    echo "ERROR: Could not connect to PostgreSQL with the standard admin credentials."
    exit 1
}

# Copy the HammerDB scripts from the repository
TARGET_DIR="HammerDB-4.12/scripts/python/postgres/tprocc"

# Copy the scripts
cp "$REPO_DIR"/scripts/hammerdb/pg_tprocc_buildschema.py "$TARGET_DIR"/
cp "$REPO_DIR"/scripts/hammerdb/pg_tprocc_run.py "$TARGET_DIR"/

# Update the connection details in the scripts
sed -i "s/DB_SERVER_IP/$PG_HOST/g" "$TARGET_DIR"/pg_tprocc_buildschema.py
sed -i "s/DB_SERVER_IP/$PG_HOST/g" "$TARGET_DIR"/pg_tprocc_run.py

# Set permissions
chmod -R 755 HammerDB-4.12/scripts

echo "=============================="
echo "HammerDB client setup complete!"
echo "=============================="
echo "The HammerDB scripts have been configured with connection to $PG_HOST"
echo "Using standard credentials: admin/password"
echo ""
echo "To build the schema, run:"
echo "cd HammerDB-4.12"
echo "./hammerdbcli py auto ./scripts/python/postgres/tprocc/pg_tprocc_buildschema.py"
echo ""
echo "To run the benchmark, run:"
echo "cd HammerDB-4.12"
echo "./hammerdbcli py auto ./scripts/python/postgres/tprocc/pg_tprocc_run.py"

