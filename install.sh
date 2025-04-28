#!/usr/bin/env bash

# Global verbosity flag (default: off)
VERBOSE=false

# Function to print messages only in verbose mode
log() {
    
    local force_output="$2"  # New argument to force output even if VERBOSE is off

    if [[ "$VERBOSE" == "true" || "$force_output" == "true" ]]; then
        echo "[VERBOSE] $1"
    fi
}




# Function to detect OS and determine the package manager
detect_os() {
    log "Detecting operating system..."
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "$ID" in
            debian|ubuntu)
                PACKAGE_MANAGER="apt"
                ;;
            almalinux|fedora|centos|rhel)
                PACKAGE_MANAGER="dnf"
                ;;
            alpine)
                PACKAGE_MANAGER="apk"
                ;;
            *)
                echo "Unsupported OS: $ID"
                exit 1
                ;;
        esac
        log "Detected OS: $ID, using package manager: $PACKAGE_MANAGER"
    else
        echo "Cannot determine the OS. /etc/os-release file is missing."
        exit 1
    fi
}

# Function to install Docker
install_docker() {
    log "Installing Docker on $ID using $PACKAGE_MANAGER..."

    case "$PACKAGE_MANAGER" in
        apt)
            log "Updating package lists..."
            sudo apt update
            sudo apt install -y ca-certificates curl gnupg
            log "Setting up Docker repository..."
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo rm -f /etc/apt/keyrings/docker.gpg
            
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            log "Installing Docker..."
            sudo apt update
            sudo apt install -y docker-ce docker-ce-cli containerd.io || {
                log "Docker is not available for Ubuntu Noble. Installing docker.io instead..."
                sudo apt install -y docker.io
            }
            ;;
        dnf)
            log "Installing Docker using DNF..."
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager --add-repo "https://download.docker.com/linux/${ID}/docker-ce.repo"
            sudo dnf install -y docker-ce docker-ce-cli containerd.io
            ;;
        apk)
            log "Installing Docker using APK..."
            sudo apk add --update docker openrc
            sudo rc-update add docker boot
            ;;
        *)
            echo "Package manager not supported for Docker installation."
            exit 1
            ;;
    esac

    log "Enabling and starting Docker service..."
    sudo systemctl enable docker || log "Docker service enable failed (maybe not installed)."
    sudo systemctl start docker || log "Docker service start failed (maybe not installed)."
    echo "Docker installation complete!"
}

# Function to install Docker Compose (Version 2)
install_docker_compose() {
    log "Installing Docker Compose..."
    sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose version
    echo "Docker Compose installation complete!"
}

# Function to configure Docker Daemon (MTU and Logging)
configure_docker_daemon() {
    log "Configuring Docker Daemon..."

    DEFAULT_MTU="1500"
    DEFAULT_LOGGING_DRIVER="json-file"

    MTU_VALUE="${MTU:-$DEFAULT_MTU}"
    LOGGING_DRIVER_VALUE="${LOGGING_DRIVER:-$DEFAULT_LOGGING_DRIVER}"

    sudo mkdir -p /etc/docker

    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "mtu": $MTU_VALUE,
    "log-driver": "$LOGGING_DRIVER_VALUE"
}
EOF

    log "Docker Daemon configured with MTU=$MTU_VALUE and Log Driver=$LOGGING_DRIVER_VALUE"

    sudo systemctl restart docker
    log "Docker restarted successfully!"
}

# Function to create users
create_users() {
    log "Creating users..." "true"  # Always display this message

    for user in "${users_list[@]}"; do
        if id "$user" &>/dev/null; then
            log "User '$user' already exists." "true"  # Always print this
        else
            log "Creating user '$user'." "true"  # Always print this
            sudo useradd -m -s /bin/bash "$user"
            log "User '$user' created successfully." "true"  # Always print this
        fi
    done
}


# Function to create groups and add users
create_groups() {
    log "Creating groups..." "true"
    for group in "${groups_list[@]}"; do
        if getent group "$group" &>/dev/null; then
            log "Group '$group' already exists.""true"
        else
            log "Creating group '$group'." "true"
            sudo groupadd "$group"
            log "Group '$group' created successfully." "true"
        fi

        for user in "${users_list[@]}"; do
            if id "$user" &>/dev/null; then
                if groups "$user" | grep -q "\b$group\b"; then
                    log "User '$user' is already a member of '$group'." "true"
                else
                    log "Adding user '$user' to group '$group'." "true"
                    sudo usermod -aG "$group" "$user"
                    log "User '$user' added to group '$group'." "true"
                fi
            else
                log "User '$user' does not exist. Skipping addition to group '$group'." "true"
            fi
        done
    done
}

# Argument Parsing
users_list=()
groups_list=()
MTU=""
LOGGING_DRIVER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --users)
            shift
            IFS=' ' read -r -a users_list <<< "$1"
            shift
            ;;
        --groups)
            shift
            IFS=' ' read -r -a groups_list <<< "$1"
            shift
            ;;
        --mtu)
            shift
            MTU="$1"
            shift
            ;;
        --log-driver)
            shift
            LOGGING_DRIVER="$1"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log "Warning: Unknown argument '$1' ignored."
            shift
            ;;
    esac
done

detect_os
install_docker
install_docker_compose
configure_docker_daemon
create_users
create_groups