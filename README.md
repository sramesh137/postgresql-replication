# PostgreSQL Logical Replication with Docker

This project demonstrates setting up **PostgreSQL logical replication** using Docker containers. It includes a primary (publisher) database and multiple secondary (subscriber) databases, configured for testing replication limits, slot exhaustion, and data synchronization.

Logical replication allows replicating specific tables or databases at the logical level, enabling real-time data sync for applications like payment systems, reporting, or failover setups.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
  - [1. Clone the Repository](#1-clone-the-repository)
  - [2. Configure docker-compose.yml](#2-configure-docker-composeyml)
  - [3. Initialize Databases](#3-initialize-databases)
  - [4. Start Containers](#4-start-containers)
- [Usage](#usage)
  - [Connect to Databases](#connect-to-databases)
  - [Set Up Replication](#set-up-replication)
  - [Add More Tables](#add-more-tables)
  - [Monitor Replication](#monitor-replication)
- [Docker Logs and Debugging](#docker-logs-and-debugging)
- [Testing Slot Exhaustion](#testing-slot-exhaustion)
- [Key Learnings](#key-learnings)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)
- [References](#references)

## Features
- **Docker-Based Setup:** Easy-to-run containers for primary and secondaries.
- **Publication/Subscription Model:** Primary publishes changes; secondaries subscribe and replicate.
- **Slot Limit Testing:** Demonstrates `max_replication_slots` exhaustion and recovery.
- **Multi-Table Support:** Add tables to publications dynamically.
- **Monitoring:** Queries and logs for replication status.

## Prerequisites
- **Docker and Docker Compose:** Install from [Docker's website](https://www.docker.com/).
- **Basic PostgreSQL Knowledge:** Familiarity with SQL and replication concepts.
- **Mac/Linux Terminal:** For running commands.

## Project Structure
```
postgresql-replication/
├── docker-compose.yml    # Container definitions
├── primary-init/
│   └── init.sql          # Primary DB initialization (creates tables and data)
├── secondary-init/
│   └── init.sql          # Secondary DB initialization (optional)
└── README.md             # This file
```

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/sramesh137/postgresql-replication.git
cd postgresql-replication
```

### 2. Configure docker-compose.yml
The file defines:
- **Primary:** Publisher with logical replication enabled (`wal_level=logical`, `max_replication_slots=3`).
- **Secondaries:** Subscribers (add more as needed).

Example `docker-compose.yml`:
```yaml
version: '3.8'

services:
  postgres-primary:
    image: postgres:15
    container_name: postgres-primary
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - ./primary-data:/var/lib/postgresql/data
      - ./primary-init:/docker-entrypoint-initdb.d
    command: ["postgres", "-c", "wal_level=logical", "-c", "max_replication_slots=3", "-c", "max_wal_senders=10"]
    networks:
      - postgres-net

  postgres-secondary:
    image: postgres:15
    container_name: postgres-secondary
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5433:5432"
    volumes:
      - ./secondary-data:/var/lib/postgresql/data
      - ./secondary-init:/docker-entrypoint-initdb.d
    depends_on:
      - postgres-primary
    networks:
      - postgres-net

  # Add more secondaries (e.g., postgres-secondary2) for testing

networks:
  postgres-net:
    driver: bridge
```

### 3. Initialize Databases
- **Primary (`init.sql`):** Creates `test_table` and inserts initial data.
- **Secondary:** Optionally create the same schema manually (replication copies data but not schema).

### 4. Start Containers
```bash
docker-compose up -d
```

Verify:
```bash
docker-compose ps
```

## Usage

### Connect to Databases
- **Primary:** `psql -h localhost -p 5432 -U postgres -d testdb`
- **Secondary:** `psql -h localhost -p 5433 -U postgres -d testdb` (adjust port for others)

### Set Up Replication
1. **On Primary: Create Publication**
   ```sql
   CREATE PUBLICATION test_pub FOR ALL TABLES;
   ```

2. **On Secondary: Create Table Schema**
   ```sql
   CREATE TABLE test_table (
       id SERIAL PRIMARY KEY,
       name VARCHAR(50),
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

3. **On Secondary: Create Subscription**
   ```sql
   CREATE SUBSCRIPTION test_sub
   CONNECTION 'host=postgres-primary port=5432 user=postgres password=password dbname=testdb'
   PUBLICATION test_pub;
   ```

4. **Test Replication**
   - Insert on primary: `INSERT INTO test_table (name) VALUES ('New Data');`
   - Check on secondary: `SELECT * FROM test_table;`

### Add More Tables
- On primary: `CREATE TABLE new_table (...);`
- Add to publication: `ALTER PUBLICATION test_pub ADD TABLE new_table;`
- Refresh subscription: `ALTER SUBSCRIPTION test_sub REFRESH PUBLICATION;`

### Monitor Replication
- **Slots on Primary:** `SELECT slot_name, active FROM pg_replication_slots;`
- **Subscription Status on Secondary:** `SELECT subname, substate FROM pg_stat_subscription;`
- **Logs:** `docker-compose logs postgres-primary`

## Docker Logs and Debugging

Docker logs are essential for troubleshooting replication issues, connection problems, and understanding what's happening inside your containers.

### View Logs for All Containers
```bash
docker-compose logs
```

### View Logs for a Specific Container
```bash
# Primary database logs
docker-compose logs postgres-primary

# Secondary database logs
docker-compose logs postgres-secondary
```

### Follow Logs in Real-Time
Use the `-f` flag to stream logs as they occur:
```bash
# Follow primary logs
docker-compose logs -f postgres-primary

# Follow all containers
docker-compose logs -f
```

### View Recent Logs
Show only the last N lines (e.g., last 100 lines):
```bash
docker-compose logs --tail=100 postgres-primary
```

### View Logs with Timestamps
```bash
docker-compose logs -t postgres-primary
```

### Common Log Patterns to Look For

**Successful Replication Setup:**
```
LOG:  logical replication apply worker for subscription "test_sub" has started
LOG:  logical replication table synchronization worker for subscription "test_sub", table "test_table" has started
LOG:  logical replication table synchronization worker for subscription "test_sub", table "test_table" has finished
```

**Replication Slot Issues:**
```
ERROR:  all replication slots are in use
HINT:  Free a replication slot or increase max_replication_slots
```

**Connection Errors:**
```
FATAL:  password authentication failed for user "postgres"
could not connect to the publisher: connection refused
```

**Duplicate Key Errors:**
```
ERROR:  duplicate key value violates unique constraint "test_table_pkey"
```

### Using Docker Commands Directly
```bash
# List running containers
docker ps

# View logs using container name
docker logs postgres-primary

# Follow logs with Docker
docker logs -f postgres-primary

# View logs from last 5 minutes
docker logs --since 5m postgres-primary

# Save logs to a file
docker logs postgres-primary > primary-logs.txt 2>&1
```

### Accessing Container Shell for Advanced Debugging
```bash
# Access primary container bash
docker exec -it postgres-primary bash

# Check PostgreSQL logs inside the container
docker exec -it postgres-primary cat /var/lib/postgresql/data/log/postgresql-*.log

# Check processes inside container
docker exec -it postgres-primary ps aux
```

### Stop and Remove Containers (for cleanup)
```bash
# Stop all containers
docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v

# View container resource usage
docker stats
```

## Testing Slot Exhaustion
1. Set `max_replication_slots=3` in `docker-compose.yml`.
2. Create 3 subscriptions (one per secondary).
3. Attempt a 4th: It fails with "all replication slots are in use".
4. **Fix:** Drop a subscription or increase the limit, then restart containers.

## Key Learnings
- **Replication Slots:** Tied to subscriptions, not replicas. Each sub uses 1+ slots (extra for sync).
- **Sync Process:** Temporary slots created for initial data copy; dropped after completion.
- **Limits:** `max_replication_slots` prevents resource exhaustion; monitor and adjust.
- **Errors:** Common issues include duplicate keys, slot exhaustion, and connection failures.
- **Best Practices:** Use unique subscription names, ensure schema matches, and test in isolated environments.

## Troubleshooting
- **Replication Not Working:** Check logs for errors; verify connections and schema.
- **Slot Errors:** Increase `max_replication_slots` or free slots by dropping subscriptions.
- **Data Mismatch:** Ensure primary and secondary schemas are identical before subscribing.
- **Container Issues:** `docker-compose down -v` to reset volumes.

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request. For major changes:
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License
This project is licensed under the MIT License - feel free to use it for educational and commercial purposes.

## Author
**Ramesh S**
- GitHub: [@sramesh137](https://github.com/sramesh137)

## References
- [PostgreSQL Logical Replication Docs](https://www.postgresql.org/docs/current/logical-replication.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Replication Slots](https://www.postgresql.org/docs/current/warm-standby.html#STREAMING-REPLICATION-SLOTS)

---
⭐ If you found this project helpful, please consider giving it a star!
