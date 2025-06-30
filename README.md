# Shell Script 
This project contains a modular and automated Bash script that installs and configures Docker and Docker Compose across multiple Linux distributions. It also supports system provisioning by managing users, groups, and Docker daemon settings.

> Originally developed for the **IKT114-G 25V – IT Orchestration** course at the University of Agder.

## Features

-  **OS Detection** (Ubuntu, Alpine, Fedora, etc.)
-  **Docker & Docker Compose Installation**
-  **Docker Daemon Configuration**
  - MTU setting
  - Logging driver configuration
-  **User & Group Creation**
-  **Verbose Mode** for debugging and logging

## Usage

```bash
./install.sh \
  --users "alice bob" \
  --groups "devops docker" \
  --mtu 1450 \
  --log-driver journald \
  --verbose
