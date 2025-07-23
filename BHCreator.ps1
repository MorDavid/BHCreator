# Start PowerShell script
$startString = "BHCREATOR"

# Function to generate a random password
function Generate-RandomPassword {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    $random = -join ((1..8) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return "$startString$random"
}

# Function to check log entry
function Get-BloodHoundInitialPassword {
    $containers = docker ps -a --format "{{.ID}} {{.Image}}" | Where-Object { $_ -match '_bloodhound|specterops/bloodhound' } | ForEach-Object { ($_ -split ' ')[0] }
    foreach ($container in $containers) {
        $log = docker logs $container 2>$null | Select-String "Initial Password Set To"
        if ($log) {
            $password = $log -replace '.*Initial Password Set To:\s*', '' -replace '[\"}]', '' -replace '\s+$', ''
            return $password
        }
    }
    return $null
}

# Generate random password
$randomPassword = Generate-RandomPassword

# Check admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as administrator."
    exit 1
}

# Check Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "[X] Docker is not installed."
    exit 1
}

# Check Docker Compose
if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    Write-Host "[+] Docker Compose is already installed."
} else {
    Write-Host "[X] Docker Compose is not installed. Installing..."
    $composeUrl = "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
    Invoke-WebRequest $composeUrl -OutFile "C:\Program Files\Docker\docker-compose.exe"
    if ($?) {
        Write-Host "[+] Docker Compose installed."
    } else {
        Write-Error "[X] Failed to install Docker Compose."
        exit 1
    }
}

# Containers and Volumes
$containers = "bloodhound_docker-app-db-1", "bloodhound_docker-graph-db-1", "bloodhound_docker-bloodhound-1"
$volumes = "bloodhound_docker_postgres-data", "bloodhound_docker_neo4j-data"

foreach ($container in $containers) {
    $isRunning = docker ps --filter "name=$container" --format "{{.ID}}"
    if ($isRunning) {
        Write-Host "[-] $container is running. Stopping and removing..."
        docker stop $container | Out-Null
        docker rm $container | Out-Null
    }
}

foreach ($volume in $volumes) {
    $exists = docker volume ls -q --filter "name=$volume"
    if ($exists) {
        Write-Host "[-] $volume exists. Removing volume..."
        docker volume rm $volume | Out-Null
    }
}

$dir = "bloodhound_docker"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
    Write-Host "[+] Directory '$dir' created."
} else {
    Write-Host "[+] Directory '$dir' already exists."
}
Set-Location $dir

Write-Host "[+] Download .env.example"
Invoke-WebRequest https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/.env.example -OutFile ".env"
Write-Host "[+] Download bloodhound.config.json"
Invoke-WebRequest https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/bloodhound.config.json -OutFile "bloodhound.config.json"
Write-Host "[+] Download docker-compose.yml"
Invoke-WebRequest https://raw.githubusercontent.com/SpecterOps/BloodHound/main/examples/docker-compose/docker-compose.yml -OutFile "docker-compose.yml"

# Modify files
(gc bloodhound.config.json) -replace "spam@example.com", "info@mdapp.co.il" `
    -replace '"Bloodhound"', '"Mor"' `
    -replace '"Admin"', '""' | Set-Content bloodhound.config.json

(gc .env) -replace 'BLOODHOUND_HOST=127.0.0.1', 'BLOODHOUND_HOST=0.0.0.0' `
    -replace 'BLOODHOUND_PORT=8080', 'BLOODHOUND_PORT=6990' `
    -replace '# Default Admin', '# Default Admin - MD Edison' `
    -replace 'bloodhoundcommunityedition', $randomPassword `
    -replace '#bhe_default_admin_principal_name=', 'bhe_default_admin_principal_name=md' `
    -replace '#bhe_default_admin_password=', 'bhe_default_admin_password=Aa123456789!' `
    -replace '#bhe_default_admin_email_address=', 'bhe_default_admin_email_address=info@mdapp.co.il' `
    -replace '#bhe_default_admin_first_name=', 'bhe_default_admin_first_name=Mor' `
    -replace '#bhe_default_admin_last_name=', 'bhe_default_admin_last_name=BH' | Set-Content .env

(gc docker-compose.yml) -replace '127.0.0.1:\$\{NEO4J_DB_PORT:-7687\}:7687', '0.0.0.0:${NEO4J_DB_PORT:-7687}:7687' `
    -replace '127.0.0.1:\$\{NEO4J_WEB_PORT:-7474\}:7474', '0.0.0.0:${NEO4J_WEB_PORT:-7474}:7474' `
    -replace '# volumes:', 'volumes:' `
    -replace '#   - .\/bloodhound.config.json:\/bloodhound.config.json:ro', '  - ./bloodhound.config.json:/bloodhound.config.json:ro' | Set-Content docker-compose.yml

# Run Docker Compose
Write-Host "[+] docker-compose up -d"
docker-compose up -d

Write-Host "`n[+] BloodHound's credentials:"
Write-Host "Email: info@mdapp.co.il"

Write-Host "Waiting for password..."
$password = $null
while (-not $password) {
    $password = Get-BloodHoundInitialPassword
    Start-Sleep -Seconds 1
}

Write-Host "Password: $password`n"
Write-Host "[+] Neo4j's credentials:"
Write-Host "Username: neo4j"
Write-Host "Password: $randomPassword`n"
Write-Host "[+] Done, Happy Graphing!"
