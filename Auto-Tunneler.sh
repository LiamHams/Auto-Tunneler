#!/bin/bash

# Get the server's public IPv4 automatically
LOCAL_IPV4=$(curl -s4 ifconfig.me)

# Menu
echo "1. Create Tunnels"
echo "2. Delete Tunnels"
echo "3. Create and Enable Auto-Start Service"
read -p "Please select an option [1, 2, or 3]: " option

if [ "$option" == "1" ]; then
    read -p "Please enter the remote IPv4 for 6to4tun_IR_1: " REMOTE_IPV4_1
    read -p "Please enter the remote IPv4 for 6to4tun_IR_2: " REMOTE_IPV4_2

    ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IPV4_1 local $LOCAL_IPV4
    ip -6 addr add f100::1/8 dev 6to4tun_IR_1
    ip link set 6to4tun_IR_1 mtu 1480
    ip link set 6to4tun_IR_1 up

    ip tunnel add 6to4tun_IR_2 mode sit remote $REMOTE_IPV4_2 local $LOCAL_IPV4
    ip -6 addr add f200::1/8 dev 6to4tun_IR_2
    ip link set 6to4tun_IR_2 mtu 1480
    ip link set 6to4tun_IR_2 up

    ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote f100::2 local f100::1
    ip addr add 99.99.1.1/30 dev GRE6Tun_IR_1
    ip link set GRE6Tun_IR_1 mtu 1436
    ip link set GRE6Tun_IR_1 up

    ip -6 tunnel add GRE6Tun_IR_2 mode ipip6 remote f200::2 local f200::1
    ip addr add 99.98.1.1/30 dev GRE6Tun_IR_2
    ip link set GRE6Tun_IR_2 mtu 1436
    ip link set GRE6Tun_IR_2 up

    echo "Tunnels created successfully."

elif [ "$option" == "2" ]; then
    ip tunnel del 6to4tun_IR_2
    ip tunnel del GRE6Tun_IR_2
    ip tunnel del 6to4tun_IR_1
    ip tunnel del GRE6Tun_IR_1

    echo "Tunnels deleted successfully."

elif [ "$option" == "3" ]; then
    # Create systemd service file
    SERVICE_PATH="/etc/systemd/system/tunnel-setup.service"
    
    cat <<EOF | sudo tee $SERVICE_PATH
[Unit]
Description=Tunnel Setup Service
After=network.target

[Service]
ExecStart=/usr/local/bin/tunnel-setup.sh 1

[Install]
WantedBy=multi-user.target
EOF

    # Move script to /usr/local/bin
    sudo cp "$0" /usr/local/bin/tunnel-setup.sh
    sudo chmod +x /usr/local/bin/tunnel-setup.sh

    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable tunnel-setup.service
    sudo systemctl start tunnel-setup.service

    echo "Auto-start service created and enabled successfully."

else
    echo "Invalid option. Please select 1, 2, or 3."
fi
