#!/bin/bash

# دریافت IP سرور به صورت خودکار
LOCAL_IP=$(curl -s ifconfig.me)

# منو
echo "1. ساخت تانل‌ها"
echo "2. حذف تانل‌ها"
echo "3. ساخت و فعال‌سازی سرویس خودکار"
read -p "لطفا گزینه مورد نظر را انتخاب کنید [1، 2 یا 3]: " option

if [ "$option" == "1" ]; then
    read -p "لطفا آدرس IP ریموت برای 6to4tun_IR_1 را وارد کنید: " REMOTE_IP1
    read -p "لطفا آدرس IP ریموت برای 6to4tun_IR_2 را وارد کنید: " REMOTE_IP2

    ip tunnel add 6to4tun_IR_1 mode sit remote $REMOTE_IP1 local $LOCAL_IP
    ip -6 addr add f100::1/8 dev 6to4tun_IR_1
    ip link set 6to4tun_IR_1 mtu 1480
    ip link set 6to4tun_IR_1 up

    ip -6 tunnel add GRE6Tun_IR_1 mode ipip6 remote f100::2 local f100::1
    ip addr add 99.99.1.1/30 dev GRE6Tun_IR_1
    ip link set GRE6Tun_IR_1 mtu 1436
    ip link set GRE6Tun_IR_1 up

    ip tunnel add 6to4tun_IR_2 mode sit remote $REMOTE_IP2 local $LOCAL_IP
    ip -6 addr add f200::1/8 dev 6to4tun_IR_2
    ip link set 6to4tun_IR_2 mtu 1480
    ip link set 6to4tun_IR_2 up

    ip -6 tunnel add GRE6Tun_IR_2 mode ipip6 remote f200::2 local f200::1
    ip addr add 99.98.1.1/30 dev GRE6Tun_IR_2
    ip link set GRE6Tun_IR_2 mtu 1436
    ip link set GRE6Tun_IR_2 up

    echo "تانل‌ها با موفقیت ساخته شدند."

elif [ "$option" == "2" ]; then
    ip tunnel del 6to4tun_IR_2
    ip tunnel del GRE6Tun_IR_2
    ip tunnel del 6to4tun_IR_1
    ip tunnel del GRE6Tun_IR_1

    echo "تانل‌ها با موفقیت حذف شدند."

elif [ "$option" == "3" ]; then
    # ساخت فایل سرویس systemd
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

    # انتقال اسکریپت به /usr/local/bin
    sudo cp "$0" /usr/local/bin/tunnel-setup.sh
    sudo chmod +x /usr/local/bin/tunnel-setup.sh

    # فعال‌سازی سرویس
    sudo systemctl daemon-reload
    sudo systemctl enable tunnel-setup.service
    sudo systemctl start tunnel-setup.service

    echo "سرویس خودکار با موفقیت ساخته و فعال شد."

else
    echo "گزینه نامعتبر است. لطفا 1، 2 یا 3 را انتخاب کنید."
fi
