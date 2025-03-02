#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is available
port_available() {
  if command_exists ss; then
    ! ss -tuln | grep -q ":$1 "
  elif command_exists netstat; then
    ! netstat -tuln | grep -q ":$1 "
  else
    echo "Error: Neither 'ss' nor 'netstat' is available. Cannot check port availability."
    exit 1
  fi
}

# Function to validate a port number
validate_port() {
  if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
    return 0
  else
    echo "Error: Port must be a number between 1 and 65535."
    return 1
  fi
}

# Function to validate a password
validate_password() {
  if [[ ${#1} -lt 8 ]]; then
    echo "Error: Password must be at least 8 characters long."
    return 1
  fi
  return 0
}

# Step 1: Check if Docker is installed
if ! command_exists docker; then
  echo "Error: Docker is not installed. Please install Docker first."
  echo "Follow the instructions here: https://docs.docker.com/get-docker/"
  exit 1
fi

# Step 2: Check if Docker Compose is available
if ! docker compose version >/dev/null 2>&1; then
  echo "Error: Docker Compose v2 is not available. Please ensure Docker Compose v2 is installed."
  echo "Follow the instructions here: https://docs.docker.com/compose/install/"
  exit 1
fi

# Step 3: Ask for installation directory
DEFAULT_DIR="$HOME/firefly-iii"
read -p "Enter the installation directory (default: $DEFAULT_DIR): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}

# Create the installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || { echo "Failed to change to directory $INSTALL_DIR"; exit 1; }

# Step 4: Ask if the user wants to set up the Data Importer
read -p "Do you want to set up the Firefly III Data Importer? (y/n): " SETUP_IMPORTER
SETUP_IMPORTER=${SETUP_IMPORTER:-n}

# Step 5: Download required files
echo "Downloading configuration files..."
curl_with_fallback() {
  if ! curl -o "$1" "$2"; then
    echo "Error: Failed to download $1 from $2"
    exit 1
  fi
}

if [[ "${SETUP_IMPORTER,,}" == "y" ]]; then
  curl_with_fallback docker-compose.yml https://raw.githubusercontent.com/firefly-iii/docker/main/docker-compose-importer.yml
  curl_with_fallback .importer.env https://raw.githubusercontent.com/firefly-iii/data-importer/main/.env.example
else
  curl_with_fallback docker-compose.yml https://raw.githubusercontent.com/firefly-iii/docker/main/docker-compose.yml
fi

curl_with_fallback .env https://raw.githubusercontent.com/firefly-iii/firefly-iii/main/.env.example
curl_with_fallback .db.env https://raw.githubusercontent.com/firefly-iii/docker/main/database.env

# Step 6: Gather user input for Firefly III
while true; do
  read -p "Enter the port for Firefly III (default: 80): " FF_PORT
  FF_PORT=${FF_PORT:-80}
  if validate_port "$FF_PORT" && port_available "$FF_PORT"; then
    break
  else
    echo "Port $FF_PORT is invalid or already in use. Please choose a different port."
  fi
done

while true; do
  read -p "Enter the database name (default: firefly): " DB_NAME
  DB_NAME=${DB_NAME:-firefly}
  if [[ -n "$DB_NAME" ]]; then
    break
  else
    echo "Error: Database name cannot be empty."
  fi
done

while true; do
  read -p "Enter the database user (default: firefly): " DB_USER
  DB_USER=${DB_USER:-firefly}
  if [[ -n "$DB_USER" ]]; then
    break
  else
    echo "Error: Database user cannot be empty."
  fi
done

while true; do
  read -p "Enter the database password (default: firefly): " DB_PASSWORD
  DB_PASSWORD=${DB_PASSWORD:-firefly}
  if validate_password "$DB_PASSWORD"; then
    break
  fi
done

while true; do
  read -p "Enter the database root password (default: firefly_root): " DB_ROOT_PASSWORD
  DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-firefly_root}
  if validate_password "$DB_ROOT_PASSWORD"; then
    break
  fi
done

# Step 7: Data Importer setup (if enabled)
if [[ "${SETUP_IMPORTER,,}" == "y" ]]; then
  while true; do
    read -p "Enter the port for the Data Importer (default: 81): " IMPORTER_PORT
    IMPORTER_PORT=${IMPORTER_PORT:-81}
    if validate_port "$IMPORTER_PORT" && port_available "$IMPORTER_PORT"; then
      break
    else
      echo "Port $IMPORTER_PORT is invalid or already in use. Please choose a different port."
    fi
  done
fi

# Step 8: Ask if the user wants to set up the cron job
read -p "Do you want to set up the Firefly III cron job? (y/n): " SETUP_CRON
SETUP_CRON=${SETUP_CRON:-n}

if [[ "${SETUP_CRON,,}" == "y" ]]; then
  if ! command_exists openssl; then
    echo "Error: openssl is not installed. Please install openssl to generate the STATIC_CRON_TOKEN."
    exit 1
  fi
  STATIC_CRON_TOKEN=$(openssl rand -hex 16)
fi

# Step 9: Update .env files
echo "Updating configuration files..."

# Update Firefly III .env file
sed -i "s|APP_KEY=.*|APP_KEY=$(openssl rand -hex 16)|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env

# Update database .db.env file
sed -i "s|^MYSQL_RANDOM_ROOT_PASSWORD=yes|MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD|" .db.env
sed -i "s|MYSQL_DATABASE=.*|MYSQL_DATABASE=$DB_NAME|" .db.env
sed -i "s|MYSQL_USER=.*|MYSQL_USER=$DB_USER|" .db.env
sed -i "s|MYSQL_PASSWORD=.*|MYSQL_PASSWORD=$DB_PASSWORD|" .db.env

# Update Data Importer .importer.env file (if enabled)
if [[ "${SETUP_IMPORTER,,}" == "y" ]]; then
  sed -i "s|FIREFLY_III_URL=.*|FIREFLY_III_URL=http://app:8080|" .importer.env
  if [[ "$FF_PORT" == "80" ]]; then
    sed -i "s|VANITY_URL=.*|VANITY_URL=http://localhost|" .importer.env
  else
    sed -i "s|VANITY_URL=.*|VANITY_URL=http://localhost:$FF_PORT|" .importer.env
  fi
  sed -i '/FIREFLY_III_ACCESS_TOKEN/d' .importer.env
fi

# Update Firefly III port in docker-compose.yml
sed -i "s|80:8080|$FF_PORT:8080|" docker-compose.yml

# Update Data Importer port in docker-compose.yml (if enabled)
if [[ "${SETUP_IMPORTER,,}" == "y" ]]; then
  sed -i "s|81:8080|$IMPORTER_PORT:8080|" docker-compose.yml
fi

# Update cron job in docker-compose.yml (if enabled)
if [[ "${SETUP_CRON,,}" == "y" ]]; then
  echo "STATIC_CRON_TOKEN=$STATIC_CRON_TOKEN" >> .env
  sed -i "s|REPLACEME|$STATIC_CRON_TOKEN|" docker-compose.yml
else
  sed -i '/cron:/,/^ *$/d' docker-compose.yml
fi

# Step 10: Start all containers
echo "Starting Docker containers..."
docker compose -f docker-compose.yml up -d --pull=always

# Step 11: Print setup completion message
echo -e "\n===== SETUP COMPLETE =====\n"
echo "Access Firefly III at http://localhost:$FF_PORT"

if [[ "${SETUP_IMPORTER,,}" == "y" ]]; then
  echo -e "\n===== DATA IMPORTER SETUP WITH OAUTH AUTHENTICATION =====\n"
  echo "Access Data Importer at http://localhost:$IMPORTER_PORT"
  echo -e "\nOAuth Authentication Flow:"
  echo "1. When you first access the Data Importer at http://localhost:$IMPORTER_PORT"
  echo "2. You'll be prompted to log in via Firefly III"
  echo "3. Click the 'Login via Firefly III' button"
  echo "4. You'll be redirected to Firefly III to authorize the Data Importer"
  echo "5. After successful authorization, you'll be redirected back to the Data Importer"
  echo "6. Now you can import your data with the proper authorization"
fi

if [[ "${SETUP_CRON,,}" == "y" ]]; then
  echo -e "\n===== CRON JOB SETUP =====\n"
  echo "Cron job is set up with STATIC_CRON_TOKEN: $STATIC_CRON_TOKEN"
fi

echo -e "\nAll configuration files are located in: $INSTALL_DIR"
echo -e "To stop the services: docker compose -f $INSTALL_DIR/docker-compose.yml down"
echo -e "To restart the services: docker compose -f $INSTALL_DIR/docker-compose.yml up -d"
echo -e "To view logs: docker compose -f $INSTALL_DIR/docker-compose.yml logs -f"
