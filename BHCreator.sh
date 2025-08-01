#!/bin/bash

# Starting string
start_string="BHCREATOR"

# Function to generate a random password
generate_password() {
    # Define a set of characters to choose from
    characters="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

    # Concatenate the starting string with a random string of 8 characters
    password="${start_string}$(head /dev/urandom | tr -dc "$characters" | head -c 8)"
    echo "$password"
}

# Function to check if the log entry is present
check_log_entry() {
    docker logs $(docker ps -a | grep "_bloodhound\|specterops/bloodhound" | awk '{print $1}') 2>/dev/null | grep "Initial Password Set To" --color=never | awk -F': ' '{print $2}' | tr -d '"}' | sed 's/.$//' | tr -d ' '
}

# Generate and print the random password
random_password=$(generate_password)
echo '  ____  _   _    ____                _             '
echo ' | __ )| | | |  / ___|_ __ ___  __ _| |_ ___  _ __ '
echo " |  _ \| |_| | | |   | '__/ _ \/ _\` | __/ _ \| '__|"
echo ' | |_) |  _  | | |___| | |  __/ (_| | || (_) | |   '
echo ' |____/|_| |_|  \____|_|  \___|\__,_|\__\___/|_|   '                                                   
echo '                                                   '
echo '                                    by Mor David   '
echo '                                                   '

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please use sudo or switch to the root user."
   exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "[X] Docker is not installed. Please install Docker before installing Docker Compose."
    exit 1
fi

# Check if Docker Compose is installed
if command -v docker-compose &> /dev/null; then
    echo "[+] Docker Compose is already installed."
else
    echo "[X] Docker Compose is not installed. Installing Docker Compose..."

    # Install Docker Compose
    curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Check if the installation was successful
    if [ $? -eq 0 ]; then
        echo "[+] Docker Compose has been installed successfully."
    else
        echo "[X] Failed to install Docker Compose. Please check for errors."
        exit 1
    fi
fi

# List of container and volumes names to check
VOLUMES=("bloodhound_docker_postgres-data" "bloodhound_docker_neo4j-data")
CONTAINERS=("bloodhound_docker-app-db-1" "bloodhound_docker-graph-db-1" "bloodhound_docker-bloodhound-1")

for CONTAINER in "${CONTAINERS[@]}"; do
    # Check if the container is running
    IS_RUNNING=$(docker ps --filter name="$CONTAINER" --format '{{.ID}}')
    if [ -n "$IS_RUNNING" ]; then
        echo "[-] $CONTAINER is running. Stopping and removing container..."
        docker container stop "$CONTAINER" > /dev/null
        docker container rm "$CONTAINER" > /dev/null
    fi
done

# List of volumes to check
for VOLUME in "${VOLUMES[@]}"; do
    # Check if the volume exists
    VOLUME_EXISTS=$(docker volume ls -q --filter name="$VOLUME")
    if [ -n "$VOLUME_EXISTS" ]; then
        echo "[-] $VOLUME exists. Removing volume..."
        docker volume rm "$VOLUME" > /dev/null
    fi
done

DIR="bloodhound_docker"
# Check if the directory does not exist
if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR"
    echo "[+] Directory '$DIR' created."
else
    echo "[+] Directory '$DIR' already exists."
fi
cd $DIR
echo '[+] Download .env.example'
curl -s https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/.env.example > ".env"
echo '[+] Download bloodhound.config.json'
curl -s https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/bloodhound.config.json > "bloodhound.config.json"
echo '[+] Download docker-compose.yml'
curl -s https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/docker-compose.yml > "docker-compose.yml"
echo '[+] Editing bloodhound.config.json'
sed -i 's/spam@example.com/info@mdapp.co.il/' bloodhound.config.json
sed -i 's/"Bloodhound"/"Mor"/' bloodhound.config.json
sed -i 's/"Admin"/""/' bloodhound.config.json
echo '[+] Editing .env'
sed -i 's/BLOODHOUND_HOST=127.0.0.1/BLOODHOUND_HOST=0.0.0.0/' .env
sed -i 's/BLOODHOUND_PORT=8080/BLOODHOUND_PORT=6990/' .env
sed -i 's/# Default Admin/# Default Admin - MD Edison/' .env
sed -i "s/bloodhoundcommunityedition/$random_password/" .env
sed -i 's/#bhe_default_admin_principal_name=/bhe_default_admin_principal_name=md/' .env
sed -i 's/#bhe_default_admin_password=/bhe_default_admin_password=Aa123456789!/' .env
sed -i 's/#bhe_default_admin_email_address=/bhe_default_admin_email_address=info@mdapp.co.il/' .env
sed -i 's/#bhe_default_admin_first_name=/bhe_default_admin_first_name=Mor/' .env
sed -i 's/#bhe_default_admin_last_name=/bhe_default_admin_last_name=BH/' .env
sed -i 's/#bhe_enable_cypher_mutations=true/bhe_enable_cypher_mutations=true/' .env
sed -i 's/#bhe_graph_query_memory_limit=0/bhe_graph_query_memory_limit=0/' .env
sed -i 's/#bhe_disable_cypher_complexity_limit=true/bhe_disable_cypher_complexity_limit=true/' .env
echo '[+] Editing docker-compose.yml'
sed -i 's/127.0.0.1:${NEO4J_DB_PORT:-7687}:7687/0.0.0.0:${NEO4J_DB_PORT:-7687}:7687/' docker-compose.yml
sed -i 's/127.0.0.1:${NEO4J_WEB_PORT:-7474}:7474/0.0.0.0:${NEO4J_WEB_PORT:-7474}:7474/' docker-compose.yml
sed -i 's/# volumes:/volumes:/' docker-compose.yml
#sed -i 's/neo4j:4.4/neo4j:latest' docker-compose.yml
sed -i 's/#   - .\/bloodhound.config.json:\/bloodhound.config.json:ro/  - .\/bloodhound.config.json:\/bloodhound.config.json:ro/' docker-compose.yml
echo '[+] docker compose up -d'
docker-compose up -d
echo ""
echo "[+] Bloodhound's credentials:"
echo 'Email: info@mdapp.co.il'
# Wait for the specific log entry
echo "Waiting for password..."
PASSWORD=""
while [ -z "$PASSWORD" ]; do
    PASSWORD=$(check_log_entry)
    if [ -n "$PASSWORD" ]; then
        break
    fi
    sleep 1
done
echo "Password: $PASSWORD"
echo ""
echo "[+] Neo4j's credentials:"
echo 'Username: neo4j'
echo "Password: $random_password"
echo ""
echo "[+] Done, Happy Graphing!"
