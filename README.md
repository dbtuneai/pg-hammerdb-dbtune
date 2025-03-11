# PostgreSQL performance tuning with HammerDB and DBtune

This repository contains scripts and instructions to replicate the performance tuning experiments described in our blog post: [Maximizing TPROC-C Performance with HammerDB and DBtune].

## Overview

This project demonstrates how to:
1. Set up a two-VM benchmarking environment
2. Configure HammerDB for TPROC-C workload generation
3. Prepare PostgreSQL 17 for testing
4. Establish baseline performance metrics
5. Use DBtune to optimize PostgreSQL performance

Our tests showed performance improvements of up to 2.14x in throughput and 4.03x in query response time.

## Repository contents

- `scripts/`: Contains setup and HammerDB scripts
  - `setup/`: VM setup scripts
  - `hammerdb/`: Modified HammerDB scripts
- `configs/`: Configuration files
  - `pgtune_recommended.conf`: PGTune recommendations

## Prerequisites

- Two Azure VMs (Standard_D8ads_v6 or equivalent) with 8 vCPUs and 32GB RAM
- Ubuntu 24.04 LTS
- PostgreSQL 17
- HammerDB 4.12 or later
- DBtune agent (see [DBtune documentation](https://docs.dbtune.com/How%20to%20get%20started/))

## Quick start

### 1. Network configuration

Before setting up the VMs, ensure:
1. Both VMs can communicate with each other on the same virtual network
2. PostgreSQL port (5432) is open in network security group (NSG) or firewall rules
3. SSH access is enabled for both VMs

```bash
# Azure example for opening PostgreSQL port
az network nsg rule create --resource-group myResourceGroup \
  --nsg-name myNetworkSecurityGroup \
  --name PostgreSQLRule \
  --protocol tcp \
  --priority 1001 \
  --destination-port-range 5432 \
  --access allow
```

### 2. Set up the VMs

#### Database VM setup
```bash
# Clone the repository
git clone https://github.com/dbtuneai/pg-hammerdb-dbtune.git
cd pg-hammerdb-dbtune

# Run the setup script
sudo ./scripts/setup/db_vm_setup.sh
```

#### Client VM setup
```bash
# Clone the repository
git clone https://github.com/dbtuneai/pg-hammerdb-dbtune.git
cd pg-hammerdb-dbtune

# Run the setup script
sudo ./scripts/setup/client_vm_setup.sh
```
The client VM setup script will:

- Install required dependencies
- Download and extract HammerDB
- Create modified HammerDB scripts with your connection details
- Test connectivity to the PostgreSQL server

### 3. Build the schema

```bash
cd ~/HammerDB-4.12
./hammerdbcli py auto ./scripts/python/postgres/tprocc/pg_tprocc_buildschema.py
```

### 4. Run the benchmark

For each experiment scenario, follow these steps:
1. PostgreSQL defaults scenario:
- Use the default PostgreSQL configuration (no changes needed)
- Run the benchmark:

```bash
cd ~/HammerDB-4.12
./hammerdbcli py auto ./scripts/python/postgres/tprocc/pg_tprocc_run.py
```
- Let it run for at least 12 hours to establish baseline performance
- Connect the DBtune agent and start a tuning session (reload-only or restart mode)
- DBtune will automatically apply the optimal configuration after completing its tuning iterations

2. PGTune scenario:
- Apply the PGTune recommended settings:
```bash
# Copy PGTune settings to PostgreSQL configuration
sudo cp configs/pgtune_recommended.conf /etc/postgresql/17/main/conf.d/pgtune.conf
# Restart PostgreSQL to apply the changes
sudo systemctl restart postgresql
```
- Run the benchmark:

```bash
cd ~/HammerDB-4.12
./hammerdbcli py auto ./scripts/python/postgres/tprocc/pg_tprocc_run.py
```
- Let it run for at least 12 hours to establish baseline performance
- Connect the DBtune agent and start a tuning session (reload-only or restart mode)
- DBtune will automatically apply the optimal configuration after completing its tuning iterations

## Experiment scenarios

We recommend running the following scenarios:
1. PGTune defaults with reload
2. PostgreSQL defaults with reload
3. PostgreSQL defaults with restart
4. PGTune defaults with restart

## Results summary

| Scenario | Initial TPS | Tuned TPS | Speedup | Initial AQR (ms) | Tuned AQR (ms) | AQR Improvement |
|----------|-------------|-----------|---------|------------------|----------------|-----------------|
| PostgreSQL defaults (reload) | 1593 | 2903 | 1.82x | 154.0 | 74.5 | 2.10x |
| PGTune defaults (reload) | 1832 | 2845 | 1.55x | 47.5 | 35.9 | 1.33x |
| PostgreSQL defaults (restart) | 1644 | 3521 | 2.14x | 145.0 | 35.9 | 4.03x |
| PGTune defaults (restart) | 1955 | 4126 | 2.11x | 52.9 | 35.0 | 1.51x |

## Detailed steps

### 1. VM setup

The Database VM hosts PostgreSQL 17 and the DBtune agent, while the Client VM runs HammerDB to generate the test workload. We use identical VM specifications (Standard_D8ads_v6 with 8 vCPUs and 32GB RAM) to ensure consistent benchmarking.

The database VM uses the NVMe ephemeral disk for PostgreSQL data storage to maximize I/O performance. We configure PostgreSQL with 300 max connections to support our 285 virtual users.

### 2. Schema creation

We create a TPROC-C schema with 500 warehouses, resulting in approximately 50GB of initial data. This is within the recommended range of 250-500 warehouses per CPU socket and provides a realistic dataset for benchmarking.

### 3. Workload configuration

We configure HammerDB with:
- 285 virtual users (close to the 300 max connections limit)
- 24-hour run duration (for establishing baseline and tuning)
- Time profiling disabled (to prevent memory issues during long runs)
- Random warehouse distribution (to simulate realistic I/O patterns)

### 4. Performance tuning

For each scenario, we:
1. Apply the initial configuration
2. Run the workload for 12+ hours to establish baseline performance
3. Connect the DBtune agent and configure a tuning session
   - Select either reload-only or restart mode
   - Set iteration duration to 10 minutes
   - Set optimization target to TPS
4. Let DBtune run through 30 iterations (approximately 5 hours)
5. DBtune automatically applies the optimal configuration it discovered

## Contributing

We welcome contributions and improvements to these scripts and methodologies. Please feel free to submit pull requests or open issues with your suggestions.
