#!/bin/bash

# Get the server's public IPv4 automatically
LOCAL_IPV4=$(curl -s4 ifconfig.me)

# Define rc.local file path
RC_LOCAL_PATH="/etc/rc.local"
RC_LOCAL_DEFAULT_PATH="/etc/default/rc-local"

# Function to add commands to rc.local
add_to_rc_local() {
    # Remove existing tunnel commands if they exist
    sed -i '/^# Tunnels setup/d' $RC_LOCAL_PATH
    sed -i '/^ip tunnel/d' $RC_LOCAL_PATH

    # Add new commands to rc.local
    cat <<EOF | sudo tee -a $RC_LOCAL_PATH
#!/bin/bash
# Tunnels setup
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
EOF

    # Ensure rc.local is executable
    sudo chmod +x $RC_LOCAL_PATH
}

# Function to delete all tunnels with specified types
delete_all_tunnels() {
    # Fetch and delete all tunnels of specific types
    for tunnel in $(ip -o link show | awk -F': ' '/6to4|ipip6|ip6gre/ {print $2}'); do
        if [[ $tunnel != "ip6gre0" && $tunnel != "NONE" ]]; then
            ip tunnel del $tunnel && echo "Deleted tunnel: $tunnel" || echo "Failed to delete tunnel: $tunnel"
        fi
    done
}

# Menu
echo "1. Create Tunnels"
echo "2. Delete Tunnels"
echo "3. Configure rc.local for Auto-Start"
echo "4. Disable Tunnels Auto-Start"
echo "5. Delete All 6to4, ipip6, and ip6gre Tunnels"
read -p "Please select an option [1, 2, 3, 4, or 5]: " option

if [ "$option" == "1" ]; then
    read -p "Please enter the remote IPv4 for 6to4tun_IR_1: " REMOTE_IPV4_1
    read -p "Please enter the remote IPv4 for 6to4tun_IR_2: " REMOTE_IPV4_2

    # Create and setup the first tunnel
    ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IPV4_1 local $LOCAL_IPV4 || { echo "Failed to add tunnel 6to4tun_IR_1"; exit 1; }
    ip -6 addr add f100::1/8 dev 6to4tun_IR_1 || { echo "Failed to add IPv6 address to 6to4tun_IR_1"; exit 1; }
    ip link set 6to4tun_IR_1 mtu 1480 || { echo "Failed to set MTU for 6to4tun_IR_1"; exit 1; }
    ip link set 6to4tun_IR_1 up || { echo "Failed to bring up 6to4tun_IR_1"; exit 1; }

    # Create and setup the second tunnel
    ip tunnel add 6to4tun_IR_2 mode sit remote $REMOTE_IPV4_2 local $LOCAL_IPV4 || { echo "Failed to add tunnel 6to4tun_IR_2"; exit 1; }
    ip -6 addr add f200::1/8 dev 6to4tun_IR_2 || { echo "Failed to add IPv6 address to 6to4tun_IR_2"; exit 1; }
    ip link set 6to4tun_IR_2 mtu 1480 || { echo "Failed to set MTU for 6to4tun_IR_2"; exit 1; }
    ip link set 6to4tun_IR_2 up || { echo "Failed to bring up 6to4tun_IR_2"; exit 1; }

    # Create and setup the GRE tunnel for the first 6to4 tunnel
    ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote f100::2 local f100::1 || { echo "Failed to add GRE tunnel GRE6Tun_IR_1"; exit 1; }
    ip addr add 99.99.1.1/30 dev GRE6Tun_IR_1 || { echo "Failed to add IPv4 address to GRE6Tun_IR_1"; exit 1; }
    ip link set GRE6Tun_IR_1 mtu 1436 || { echo "Failed to set MTU for GRE6Tun_IR_1"; exit 1; }
    ip link set GRE6Tun_IR_1 up || { echo "Failed to bring up GRE6Tun_IR_1"; exit 1; }

    # Create and setup the GRE tunnel for the second 6to4 tunnel
    ip -6 tunnel add GRE6Tun_IR_2 mode ipip6 remote f200::2 local f200::1 || { echo "Failed to add GRE tunnel GRE6Tun_IR_2"; exit 1; }
    ip addr add 99.98.1.1/30 dev GRE6Tun_IR_2 || { echo "Failed to add IPv4 address to GRE6Tun_IR_2"; exit 1; }
    ip link set GRE6Tun_IR_2 mtu 1436 || { echo "Failed to set MTU for GRE6Tun_IR_2"; exit 1; }
    ip link set GRE6Tun_IR_2 up || { echo "Failed to bring up GRE6Tun_IR_2"; exit 1; }

    echo "Tunnels created successfully."

elif [ "$option" == "2" ]; then
    ip tunnel del 6to4tun_IR_2 || { echo "Failed to delete tunnel 6to4tun_IR_2"; exit 1; }
    ip tunnel del GRE6Tun_IR_2 || { echo "Failed to delete tunnel GRE6Tun_IR_2"; exit 1; }
    ip tunnel del 6to4tun_IR_1 || { echo "Failed to delete tunnel 6to4tun_IR_1"; exit 1; }
    ip tunnel del GRE6Tun_IR_1 || { echo "Failed to delete tunnel GRE6Tun_IR_1"; exit 1; }

    echo "Tunnels deleted successfully."

elif [ "$option" == "3" ]; then
    # Get remote IPv4 addresses from the user
    read -p "Please enter the remote IPv4 for 6to4tun_IR_1: " REMOTE_IPV4_1
    read -p "Please enter the remote IPv4 for 6to4tun_IR_2: " REMOTE_IPV4_2

    # Create and configure /etc/rc.local
    sudo bash -c "echo '' > $RC_LOCAL_PATH"
    sudo bash -c 'cat <<EOF > /etc/rc.local
#!/bin/bash
# Tunnels setup
ip tunnel add 6to4tun_IR_1 mode sit remote '$REMOTE_IPV4_1' local '$LOCAL_IPV4'
ip -6 addr add f100::1/8 dev 6to4tun_IR_1
ip link set 6to4tun_IR_1 mtu 1480
ip link set 6to4tun_IR_1 up

ip tunnel add 6to4tun_IR_2 mode sit remote '$REMOTE_IPV4_2' local '$LOCAL_IPV4'
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

exit 0
EOF'
    sudo chmod +x $RC_LOCAL_PATH

    echo "Tunnels added to rc.local and auto-start configured."

elif [ "$option" == "4" ]; then
    # Disable auto-start and clear rc.local
    sudo chmod -x $RC_LOCAL_PATH
    sudo bash -c "echo '' > $RC_LOCAL_PATH"
    
    echo "Auto-start disabled for tunnels and rc.local cleared."

elif [ "$option" == "5" ]; then
    delete_all_tunnels
    echo "All 6to4, ipip6, and ip6gre tunnels deleted."

else
    echo "Invalid option. Please select 1, 2, 3, 4, or 5."
fi
