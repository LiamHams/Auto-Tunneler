#!/bin/bash

# Get the server's public IPv4 automatically
LOCAL_IPV4=$(curl -s4 ifconfig.me)

# Define rc.local file path
RC_LOCAL_PATH="/etc/rc.local"

# Function to add commands to rc.local
add_to_rc_local() {
    # Remove existing tunnel commands if they exist
    sudo sed -i '/^# Tunnels setup/d' $RC_LOCAL_PATH
    sudo sed -i '/^ip tunnel/d' $RC_LOCAL_PATH

    if [ "$TUNNEL_COUNT" -eq 1 ]; then
        cat <<EOF | sudo tee -a $RC_LOCAL_PATH
#!/bin/bash
# Tunnels setup
ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IPV4_1 local $LOCAL_IPV4
ip -6 addr add fc00::1/32 dev 6to4tun_IR_1
ip link set 6to4tun_IR_1 mtu 1480
ip link set 6to4tun_IR_1 up

ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote fc00::2 local fc00::1
ip addr add 172.20.30.1/28 dev GRE6Tun_IR_1
ip link set GRE6Tun_IR_1 mtu 1436
ip link set GRE6Tun_IR_1 up
EOF
    else
        cat <<EOF | sudo tee -a $RC_LOCAL_PATH
#!/bin/bash
# Tunnels setup
ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IPV4_1 local $LOCAL_IPV4
ip -6 addr add fc00::1/32 dev 6to4tun_IR_1
ip link set 6to4tun_IR_1 mtu 1480
ip link set 6to4tun_IR_1 up

ip tunnel add 6to4tun_IR_2 mode sit remote $REMOTE_IPV4_2 local $LOCAL_IPV4
ip -6 addr add fd00::1/32 dev 6to4tun_IR_2
ip link set 6to4tun_IR_2 mtu 1480
ip link set 6to4tun_IR_2 up

ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote fc00::2 local fc00::1
ip addr add 172.20.30.1/28 dev GRE6Tun_IR_1
ip link set GRE6Tun_IR_1 mtu 1436
ip link set GRE6Tun_IR_1 up

ip -6 tunnel add GRE6Tun_IR_2 mode ipip6 remote fd00::2 local fd00::1
ip addr add 172.20.40.1/28 dev GRE6Tun_IR_2
ip link set GRE6Tun_IR_2 mtu 1436
ip link set GRE6Tun_IR_2 up
EOF
    fi

    # Ensure rc.local is executable
    sudo chmod +x $RC_LOCAL_PATH
}

# Function to delete specified tunnels
delete_tunnels() {
    echo "Available tunnels to delete:"
    ip tunnel show | awk '{print $2}' | grep -E '^6to4|^GRE6|^tunnel6' || true

    read -p "Enter the name of the tunnel you want to delete (e.g., 6to4tun_IR_1): " tunnel_name

    if [ -n "$tunnel_name" ]; then
        ip tunnel del $tunnel_name && echo "Deleted tunnel: $tunnel_name" || echo "Failed to delete tunnel: $tunnel_name"
    else
        echo "No tunnel name provided. Please try again."
    fi
}

# Function to delete all specified tunnels, excluding system tunnels
delete_all_tunnels() {
    # Fetch and delete all tunnels of specific types, excluding system tunnels
    for tunnel in $(ip -o link show | awk -F': ' '/6to4|ipip6|gre6|tunnel6/ {print $2}' | cut -d'@' -f1); do
        if [[ "$tunnel" != "ip6gre0" && "$tunnel" != "tunnel6" ]]; then
            ip tunnel del $tunnel && echo "Deleted tunnel: $tunnel" || echo "Failed to delete tunnel: $tunnel"
        else
            echo "Skipped system tunnel: $tunnel"
        fi
    done
}

# Menu
echo "1. Create Tunnels"
echo "2. Delete Specific Tunnel"
echo "3. Configure rc.local for Auto-Start"
echo "4. Disable Tunnels Auto-Start"
echo "5. Delete All 6to4, ipip6, gre6, and tunnel6 Tunnels"
read -p "Please select an option [1, 2, 3, 4, or 5]: " option

if [ "$option" == "1" ]; then
    read -p "Do you want to create 1 tunnel or 2 tunnels? [1/2]: " TUNNEL_COUNT

    if [ "$TUNNEL_COUNT" -eq 1 ]; then
        read -p "Please enter the remote IPv4 for 6to4tun_IR_1: " REMOTE_IPV4_1

        # Create and setup the first tunnel
        ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IPV4_1 local $LOCAL_IPV4 || { echo "Failed to add tunnel 6to4tun_IR_1"; exit 1; }
        ip -6 addr add fc00::1/32 dev 6to4tun_IR_1 || { echo "Failed to add IPv6 address to 6to4tun_IR_1"; exit 1; }
        ip link set 6to4tun_IR_1 mtu 1480 || { echo "Failed to set MTU for 6to4tun_IR_1"; exit 1; }
        ip link set 6to4tun_IR_1 up || { echo "Failed to bring up 6to4tun_IR_1"; exit 1; }

        # Create and setup the GRE tunnel for the first 6to4 tunnel
        ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote fc00::2 local fc00::1 || { echo "Failed to add GRE tunnel GRE6Tun_IR_1"; exit 1; }
        ip addr add 172.20.30.1/28 dev GRE6Tun_IR_1 || { echo "Failed to add IPv4 address to GRE6Tun_IR_1"; exit 1; }
        ip link set GRE6Tun_IR_1 mtu 1436 || { echo "Failed to set MTU for GRE6Tun_IR_1"; exit 1; }
        ip link set GRE6Tun_IR_1 up || { echo "Failed to bring up GRE6Tun_IR_1"; exit 1; }

        echo "Single tunnel created successfully."

        # Configure auto-start if requested
        read -p "Do you want to configure auto-start for this tunnel? [y/n]: " AUTO_START
        if [ "$AUTO_START" == "y" ]; then
            TUNNEL_COUNT=1
            add_to_rc_local
            echo "Auto-start configured for single tunnel."
        fi

    elif [ "$TUNNEL_COUNT" -eq 2 ]; then
        read -p "Please enter the remote IPv4 for 6to4tun_IR_1: " REMOTE_IPV4_1
        read -p "Please enter the remote IPv4 for 6to4tun_IR_2: " REMOTE_IPV4_2

        # Create and setup the first tunnel
        ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IPV4_1 local $LOCAL_IPV4 || { echo "Failed to add tunnel 6to4tun_IR_1"; exit 1; }
        ip -6 addr add fc00::1/32 dev 6to4tun_IR_1 || { echo "Failed to add IPv6 address to 6to4tun_IR_1"; exit 1; }
        ip link set 6to4tun_IR_1 mtu 1480 || { echo "Failed to set MTU for 6to4tun_IR_1"; exit 1; }
        ip link set 6to4tun_IR_1 up || { echo "Failed to bring up 6to4tun_IR_1"; exit 1; }

        # Create and setup the second tunnel
        ip tunnel add 6to4tun_IR_2 mode sit remote $REMOTE_IPV4_2 local $LOCAL_IPV4 || { echo "Failed to add tunnel 6to4tun_IR_2"; exit 1; }
        ip -6 addr add fd00::1/32 dev 6to4tun_IR_2 || { echo "Failed to add IPv6 address to 6to4tun_IR_2"; exit 1; }
        ip link set 6to4tun_IR_2 mtu 1480 || { echo "Failed to set MTU for 6to4tun_IR_2"; exit 1; }
        ip link set 6to4tun_IR_2 up || { echo "Failed to bring up 6to4tun_IR_2"; exit 1; }

        # Create and setup the GRE tunnel for the first 6to4 tunnel
        ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote fc00::2 local fc00::1 || { echo "Failed to add GRE tunnel GRE6Tun_IR_1"; exit 1; }
        ip addr add 172.20.30.1/28 dev GRE6Tun_IR_1 || { echo "Failed to add IPv4 address to GRE6Tun_IR_1"; exit 1; }
        ip link set GRE6Tun_IR_1 mtu 1436 || { echo "Failed to set MTU for GRE6Tun_IR_1"; exit 1; }
        ip link set GRE6Tun_IR_1 up || { echo "Failed to bring up GRE6Tun_IR_1"; exit 1; }

        # Create and setup the GRE tunnel for the second 6to4 tunnel
        ip -6 tunnel add GRE6Tun_IR_2 mode ipip6 remote fd00::2 local fd00::1 || { echo "Failed to add GRE tunnel GRE6Tun_IR_2"; exit 1; }
        ip addr add 172.20.40.1/28 dev GRE6Tun_IR_2 || { echo "Failed to add IPv4 address to GRE6Tun_IR_2"; exit 1; }
        ip link set GRE6Tun_IR_2 mtu 1436 || { echo "Failed to set MTU for GRE6Tun_IR_2"; exit 1; }
        ip link set GRE6Tun_IR_2 up || { echo "Failed to bring up GRE6Tun_IR_2"; exit 1; }

        echo "Both tunnels created successfully."

        # Configure auto-start if requested
        read -p "Do you want to configure auto-start for these tunnels? [y/n]: " AUTO_START
        if [ "$AUTO_START" == "y" ]; then
            TUNNEL_COUNT=2
            add_to_rc_local
            echo "Auto-start configured for both tunnels."
        fi
    else
        echo "Invalid option. Please select 1 or 2."
    fi

elif [ "$option" == "2" ]; then
    delete_tunnels

elif [ "$option" == "3" ]; then
    read -p "Please enter the remote IPv4 for 6to4tun_IR_1: " REMOTE_IPV4_1
    read -p "Do you want to configure rc.local for one or two tunnels? [1/2]: " TUNNEL_COUNT

    if [ "$TUNNEL_COUNT" -eq 1 ]; then
        add_to_rc_local
        echo "Auto-start configured for single tunnel."
    elif [ "$TUNNEL_COUNT" -eq 2 ]; then
        read -p "Please enter the remote IPv4 for 6to4tun_IR_2: " REMOTE_IPV4_2
        add_to_rc_local
        echo "Auto-start configured for both tunnels."
    else
        echo "Invalid option. Please select 1 or 2."
    fi

elif [ "$option" == "4" ]; then
    # Disable auto-start and clear rc.local
    sudo chmod -x $RC_LOCAL_PATH
    sudo bash -c "echo '' > $RC_LOCAL_PATH"
    echo "Auto-start disabled and rc.local cleared."

elif [ "$option" == "5" ]; then
    delete_all_tunnels
    echo "All 6to4, ipip6, gre6, and tunnel6 tunnels deleted."

else
    echo "Invalid option. Please select 1, 2, 3, 4, or 5."
fi
