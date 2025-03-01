#!/bin/bash

# Step 1: Ask for installation directory
DEFAULT_DIR="$HOME/firefly-iii"
read -p "Enter the installation directory (default: $DEFAULT_DIR): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}

# Create the installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || { echo "Failed to change to directory $INSTALL_DIR"; exit 1; }

# Step 2: Download required files
echo "Downloading configuration files..."
curl -o docker-compose.yml https://raw.githubusercontent.com/firefly-iii/docker/main/docker-compose-importer.yml
curl -o .env https://raw.githubusercontent.com/firefly-iii/firefly-iii/main/.env.example
curl -o .importer.env https://raw.githubusercontent.com/firefly-iii/data-importer/main/.env.example
curl -o .db.env https://raw.githubusercontent.com/firefly-iii/docker/main/database.env

# Step 3: Gather user input for Firefly III
read -p "Enter the port for Firefly III (default: 80): " FF_PORT
FF_PORT=${FF_PORT:-80}

read -p "Enter the database name (default: firefly): " DB_NAME
DB_NAME=${DB_NAME:-firefly}

read -p "Enter the database user (default: firefly): " DB_USER
DB_USER=${DB_USER:-firefly}

read -p "Enter the database password: " DB_PASSWORD
read -p "Enter the database root password: " DB_ROOT_PASSWORD

# Step 4: Update .env files
echo "Updating configuration files..."

# Update Firefly III .env file
sed -i "s|APP_KEY=.*|APP_KEY=$(openssl rand -base64 32)|" .env
sed -i "s|DB_HOST=.*|DB_HOST=db|" .env
sed -i "s|DB_PORT=.*|DB_PORT=3306|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=$DB_NAME|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=$DB_USER|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=$DB_PASSWORD|" .env

# Update database .db.env file
sed -i "s|MYSQL_ROOT_PASSWORD=.*|MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD|" .db.env
sed -i "s|MYSQL_DATABASE=.*|MYSQL_DATABASE=$DB_NAME|" .db.env
sed -i "s|MYSQL_USER=.*|MYSQL_USER=$DB_USER|" .db.env
sed -i "s|MYSQL_PASSWORD=.*|MYSQL_PASSWORD=$DB_PASSWORD|" .db.env

# Step 5: Start Firefly III and the database
echo "Starting Firefly III and the database..."
docker compose -f docker-compose.yml up -d --pull=always app db

# Wait for Firefly III to initialize
echo "Waiting for Firefly III to initialize (this may take a minute)..."
sleep 30

# Step 6: Ask if the user wants to set up the Data Importer
read -p "Do you want to set up the Firefly III Data Importer? (y/n): " SETUP_IMPORTER
if [[ $SETUP_IMPORTER == "y" ]]; then
  read -p "Enter the port for the Data Importer (default: 81): " IMPORTER_PORT
  IMPORTER_PORT=${IMPORTER_PORT:-81}

  echo "To set up the Data Importer, you need a Firefly III API token."
  echo "1. Open Firefly III in your browser: http://localhost:$FF_PORT"
  echo "2. Log in and go to your Profile > OAuth."
  echo "3. Create a new Personal Access Token."
  echo "4. Copy the token and paste it below."
  read -p "Enter your Firefly III API token: " FIREFLY_III_ACCESS_TOKEN

  # Update Data Importer .importer.env file
  sed -i "s|FIREFLY_III_ACCESS_TOKEN=.*|FIREFLY_III_ACCESS_TOKEN=$FIREFLY_III_ACCESS_TOKEN|" .importer.env
  sed -i "s|FIREFLY_III_URL=.*|FIREFLY_III_URL=http://app:8080|" .importer.env

  # Update docker-compose.yml to expose Data Importer port
  sed -i "s|81:8080|$IMPORTER_PORT:8080|" docker-compose.yml

  # Start the Data Importer
  echo "Starting the Data Importer..."
  docker compose -f docker-compose.yml up -d importer
fi

# Step 7: Ask if the user wants to set up the cron job
read -p "Do you want to set up the Firefly III cron job? (y/n): " SETUP_CRON
if [[ $SETUP_CRON == "y" ]]; then
  # Generate a 32-character STATIC_CRON_TOKEN
  STATIC_CRON_TOKEN=$(openssl rand -hex 16)
  echo "STATIC_CRON_TOKEN=$STATIC_CRON_TOKEN" >> .env

  # Update cron job command in docker-compose.yml
  sed -i "s|REPLACEME|$STATIC_CRON_TOKEN|" docker-compose.yml

  # Start the cron service
  echo "Starting the cron service..."
  docker compose -f docker-compose.yml up -d cron
fi

# Step 8: Print setup completion message
echo "Setup complete! Access Firefly III at http://localhost:$FF_PORT"
if [[ $SETUP_IMPORTER == "y" ]]; then
  echo "Access Data Importer at http://localhost:$IMPORTER_PORT"
fi
if [[ $SETUP_CRON == "y" ]]; then
  echo "Cron job is set up with STATIC_CRON_TOKEN: $STATIC_CRON_TOKEN"
fi
echo "All configuration files are located in: $INSTALL_DIR"
