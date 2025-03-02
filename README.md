# Firefly III Docker Installer

A simple bash script to automate the installation and configuration of Firefly III and its Data Importer using Docker.

## Overview

This installer script sets up [Firefly III](https://www.firefly-iii.org/), a self-hosted financial management application, along with its optional Data Importer tool. The script automates the entire process using Docker and Docker Compose, making it easy to deploy Firefly III on your local machine or server.

## Prerequisites

- Docker (follow the [official installation guide](https://docs.docker.com/get-docker/))
- Docker Compose v2 (follow the [official installation guide](https://docs.docker.com/compose/install/))
- `curl` (for downloading configuration files)
- `openssl` (required for generating secure tokens)

## Features

- Automatic download of all required configuration files
- Interactive configuration of:
  - Installation directory
  - Database credentials
  - Network ports
  - Data Importer (optional)
  - Automated cron job (optional)
- Port availability checking
- Password strength validation
- Secure token generation for app key and cron job

## Usage

1. Download the installer script:
   ```bash
   curl -o firefly-iii-installer.sh https://raw.githubusercontent.com/your-username/firefly-iii-installer/main/firefly-iii-installer.sh
   ```

2. Make it executable:
   ```bash
   chmod +x firefly-iii-installer.sh
   ```

3. Run the installer:
   ```bash
   ./firefly-iii-installer.sh
   ```

4. Follow the interactive prompts to configure your installation.

## Installation Options

### Basic Installation

The script will guide you through configuring:
- Installation directory (default: `$HOME/firefly-iii`)
- Firefly III web port (default: 80)
- Database name, user, and passwords

### Data Importer Setup

When prompted, you can choose to install the Firefly III Data Importer, which helps import data from various sources into Firefly III. You'll configure:
- Data Importer web port (default: 81)
- OAuth authentication between Firefly III and the Data Importer

### Cron Job Configuration

You can optionally set up an automated cron job for Firefly III to perform scheduled tasks, such as recurring transactions and auto-budgets.

## Post-Installation

After the installation completes, you can access:
- Firefly III at `http://localhost:[configured-port]`
- Data Importer at `http://localhost:[configured-importer-port]` (if enabled)

## Management Commands

- Stop the services:
  ```bash
  docker compose -f [install-dir]/docker-compose.yml down
  ```

- Restart the services:
  ```bash
  docker compose -f [install-dir]/docker-compose.yml up -d
  ```

- View logs:
  ```bash
  docker compose -f [install-dir]/docker-compose.yml logs -f
  ```

## Security Notes

- The installer requires OpenSSL to generate secure random tokens for the application key and cron token
- If OpenSSL is not available on your system, consider these alternatives:
  ```bash
  # Using /dev/urandom (Linux/Unix systems)
  APP_KEY=$(head -c 16 /dev/urandom | xxd -p)
  
  # Using Python (if available)
  APP_KEY=$(python -c "import secrets; print(secrets.token_hex(16))")
  
  # Using Node.js (if available)
  APP_KEY=$(node -e "console.log(require('crypto').randomBytes(16).toString('hex'))")
  ```
- You should use strong passwords for the database
- Consider changing default database credentials in production environments

## Troubleshooting

- If ports are already in use, the script will prompt you to select different ones
- Ensure Docker and Docker Compose are properly installed before running the script
- Check the logs if Firefly III or the Data Importer doesn't start properly

## License

This project is licensed under the MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
