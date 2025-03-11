#!/bin/bash
# PostgreSQL VM Setup Script for HammerDB Benchmarking
# This script sets up a PostgreSQL 17 server for benchmarking
set -e

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

# Update system
echo "Updating system packages..."
apt update
apt -y upgrade

# Install prerequisites
echo "Installing prerequisites..."
apt-get -y install libpq-dev wget gnupg lsb-release

# Add PostgreSQL repository
echo "Adding PostgreSQL repository..."
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
apt update

# Set PostgreSQL version
export PGVERSION=17

# Install PostgreSQL
echo "Installing PostgreSQL ${PGVERSION}..."
apt -y install postgresql-${PGVERSION} postgresql-client-${PGVERSION}

# Stop PostgreSQL to reconfigure
systemctl stop postgresql

# Mount NVMe drive (if available)
echo "Checking for NVMe drive..."
if [ -b /dev/nvme1n1 ]; then
  echo "NVMe drive found, mounting..."
  export VAR=nvme1n1
  mkdir -p /mnt/data
  mkfs -t ext4 /dev/$VAR || { echo 'Unable to format disk' ; exit 1; }
  mount -t ext4 /dev/$VAR /mnt/data || { echo 'Unable to mount disk' ; exit 1; }
  
  echo "Copying PostgreSQL data to mounted drive..."
  rsync -av /var/lib/postgresql /mnt/data
  chmod -R 750 /mnt/data/postgresql
  chown -R postgres:postgres /mnt/data/postgresql
  
  # Update data directory in PostgreSQL configuration
  echo "Updating data directory in PostgreSQL configuration..."
  sed -i "s|data_directory = '.*'|data_directory = '/mnt/data/postgresql/${PGVERSION}/main'|" /etc/postgresql/${PGVERSION}/main/postgresql.conf
  
  # Add mount to fstab
  echo "/dev/${VAR} /mnt/data ext4 defaults 0 0" >> /etc/fstab
else
  echo "NVMe drive not found, using default storage."
fi

# Update PostgreSQL configuration
echo "Configuring PostgreSQL..."
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/${PGVERSION}/main/postgresql.conf
sed -i "s/max_connections = 100/max_connections = 300/" /etc/postgresql/${PGVERSION}/main/postgresql.conf

# Read client IP address
read -p "Enter the Client VM IP address: " CLIENT_IP

# Update pg_hba.conf to allow connections from client VM
echo "host    all             all             ${CLIENT_IP}/32         md5" >> /etc/postgresql/${PGVERSION}/main/pg_hba.conf

# Ensure PostgreSQL port is accessible
echo "Checking firewall status..."
if command -v ufw &> /dev/null; then
  echo "Configuring UFW firewall..."
  ufw allow 5432/tcp
  ufw status
elif command -v iptables &> /dev/null; then
  echo "Configuring iptables firewall..."
  iptables -A INPUT -p tcp --dport 5432 -j ACCEPT
  iptables -L
else
  echo "No firewall detected. If you have a firewall running, please ensure port 5432 is open."
fi

# Remind about NSG if using Azure
echo "IMPORTANT: If using Azure, ensure port 5432 is open in your Network Security Group (NSG)."

# Start PostgreSQL
echo "Starting PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Create a standard admin user for HammerDB
echo "Creating standard admin user for HammerDB..."
sudo -i -u postgres psql -c "CREATE USER admin WITH LOGIN SUPERUSER PASSWORD 'password';"
echo "Admin user created with username 'admin' and password 'password'"

echo "=========================="
echo "PostgreSQL setup complete!"
echo "=========================="
echo "Next steps:"
echo "1. Install DBtune agent from https://docs.dbtune.com/How%20to%20get%20started/"
echo "2. Configure firewall to allow connections from client VM"
