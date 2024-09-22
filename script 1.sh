#!/bin/bash

if ! command -v sudo microk8s kubectl &> /dev/null; then
  whiptail --msgbox "kubectl could not be found at sudo microk8s kubectl. Please check the path." 8 78
  exit 1
fi

if ! command -v whiptail &> /dev/null; then
  whiptail --msgbox "whiptail could not be found. Please install whiptail." 8 78
  exit 1
fi

while true; do
  VALUE=$(whiptail --inputbox "Please enter the verification code:" 8 78 --title "Enter Verification Code" 3>&1 1>&2 2>&3)
  EXIT_STATUS=$?
  if [ $EXIT_STATUS -ne 0 ]; then
    whiptail --msgbox "Operation cancelled." 8 78
    exit 1
  fi

  if [ -n "$VALUE" ]; then
    break
  else
    whiptail --msgbox "Verification code is required." 8 78
  fi
done

NAMESPACE="atna"

SECRET_NAME="verification-code"
KEY="VERIFICATION_CODE"
if ! sudo microk8s kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
  sudo microk8s kubectl create namespace "$NAMESPACE"
  if [ $? -ne 0 ]; then
    whiptail --msgbox "Failed to create namespace '$NAMESPACE'." 8 78
    exit 1
  fi
fi
# Check if the secret already exists
if sudo microk8s kubectl get secret "$SECRET_NAME" --namespace="$NAMESPACE" > /dev/null 2>&1; then
  sudo microk8s kubectl delete secret "$SECRET_NAME" --namespace="$NAMESPACE" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    whiptail --msgbox "Failed to delete existing secret '$SECRET_NAME'." 8 78
    exit 1
  fi
fi

# Create or update the secret in Kubernetes
sudo microk8s kubectl create secret generic "$SECRET_NAME" \
  --from-literal="$KEY=$VALUE" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | sudo microk8s kubectl apply -f -

# Check if the command was successful
if [ $? -eq 0 ]; then
  whiptail --msgbox "Secret '$SECRET_NAME' updated successfully." 8 78
else
  whiptail --msgbox "Failed to create/update secret '$SECRET_NAME'." 8 78
fi
echo "Setting up collector"

#!/bin/bash

DIR="/opt/test"

# Check if the directory exists
if [ -d "$DIR" ]; then
    echo "Directory already exists. Changing permissions."
else
    echo "Creating directory."
    mkdir "$DIR"
fi

# Change permissions
chmod 775 "$DIR"
echo "Permissions set to 775 for $DIR"

# Run the collector-config with sudo
FILE="collector-config"

# Check if the file exists
if [ -f "$FILE" ]; then
    echo "Adding execute permission to $FILE"
    chmod +x "$FILE"
    echo "Execute permission added."
else
    echo "File $FILE does not exist."
fi
if sudo ./collector-config; then
    echo "Collector setup completed successfully."
else
    echo "Failed to set up collector." >&2
    exit 1
fi
nodes_output=$(sudo microk8s kubectl get nodes -o wide)

# Extract the internal IP addresses
internal_ips=$(echo "$nodes_output" | awk '{print $6}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

# Run the kubectl command with sudo and get the output for the service
svc_output=$(sudo microk8s kubectl get svc -n atna atna-collector-service -o wide)

# Extract the port information
port=$(echo "$svc_output" | grep -oP '80:\K[0-9]+')

# Print the IP:port combinations
echo "IP:port combinations for the atna-collector-service:"
for ip in $internal_ips; do
    echo "collector service is running on $ip:$port"
done