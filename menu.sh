#!/bin/bash

# 1. ตรวจสอบสิทธิ์ Root
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;31m[ข้อผิดพลาด] กรุณารันด้วยสิทธิ์ Root (sudo -i)\e[0m"
    exit 1
fi

# 2. ตั้งค่าตัวแปรหลัก
MYIP=$(wget -qO- iboy.im/ip || curl -s ifconfig.me || echo "127.0.0.1")
ENGINE="./openvpn-install.sh"

# 3. ฟังก์ชันเตรียมเว็บดาวน์โหลด
check_webserver() {
    if ! command -v apache2 &> /dev/null && ! command -v nginx &> /dev/null; then
        apt-get update -y > /dev/null
        apt-get install apache2 -y > /dev/null
        systemctl start apache2
        systemctl enable apache2
    fi
    mkdir -p /var/www/html/download
    chmod -R 755 /var/www/html/download
}

# [01] สร้างผู้ใช้
engine_add_user() {
    check_webserver
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[!] ไม่พบไฟล์ openvpn-install.sh ในโฟลเดอร์นี้\e[0m\n"
        return
    fi
    MENU_OPTION="1" bash "$ENGINE"
    cp /root/*.ovpn /var/www/html/download/ 2>/dev/null
    cp ./*.ovpn /var/www/html/download/ 2>/dev/null
    chmod -R 644 /var/www/html/download/
    echo -e "\n\e[1;32m[สำเร็จ] สร้างและซิงค์ไฟล์ไปยังเมนู [24] แล้ว\e[0m\n"
}

# [03] ลบผู้ใช้
engine_delete_user() {
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[!] ไม่พบไฟล์ openvpn-install.sh ในโฟลเดอร์นี้\e[0m\n"
        return
    fi
    MENU_OPTION="2" bash "$ENGINE"
    rm -rf /var/www/html/download/* 2>/dev/null
    cp /root/*.ovpn /var/www/html/download/ 2>/dev/null
    chmod -R 644 /var/www/html/download/
}

# [04] เช็คคนออนไลน์
check_online() {
    echo -e "\n\e[1;32m ─────────────── รายชื่อผู้ใช้งานปัจจุบัน ───────────────\e[0m"
    if [ -f "/var/log/openvpn/status.log" ]; then
        sed -n '/ROUTING TABLE/q;p' /var/log/openvpn/status.log | grep -v "OpenVPN CLIENT LIST" | grep -v "Updated"
    elif [ -f "/var/log/openvpn-status.log" ]; then
        sed -n '/ROUTING TABLE/q;p' /var/log/openvpn-status.log | grep -v "OpenVPN CLIENT LIST" | grep -v "Updated"
    else
        echo -e "\e[1;33m[!] ยังไม่มีใครเชื่อมต่อเข้ามาในระบบในขณะนี้\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────────────\n"
}

# [10] ตั้งค่าระบบ
system_settings() {
    clear
    echo -e "\e[1;31m ─────────────── ตั้งค่าระบบ OpenVPN ───────────────\e[0m"
    echo -e "[1] • เช็คสถานะการทำงาน (Status)"
    echo -e "[2] • รีสตาร์ทบริการ (Restart OpenVPN)"
    echo -e "[3] • ดูพอร์ตที่เปิดใช้งาน (Port Check)"
    echo -e "[0] • กลับเมนูหลัก"
    echo -e "─────────────────────────────────────────────────────────────"
    echo -n "เลือกเมนูย่อย [0-3]: "
    read -r sys_choice
    sys_choice=$(echo "$sys_choice" | tr -d '\r' | tr -d ' ')
    
    case "$sys_choice" in
        1|01) systemctl status openvpn@server 2>/dev/null || systemctl status openvpn 2>/dev/null ;;
        2|02) systemctl restart openvpn@server 2>/dev/null || systemctl restart openvpn 2>/dev/null; echo "รีสตาร์ทสำเร็จแล้ว" ;;
        3|03) grep -E "^port|^proto" /etc/openvpn/server.conf 2>/dev/null || netstat -tuln | grep openvpn ;;
        *) return ;;
    esac
}

# [11] เทสสปีด
test_speed() {
    if ! command -v speedtest-cli &> /dev/null; then
        apt-get install speedtest-cli -y > /dev/null
    fi
    speedtest-cli --share
}

# [18] ข้อมูลเครื่อง VPS
show_vps_info() {
    clear
    echo -e "\e[1;31m ─────────────── ข้อมูลระบบ VPS ───────────────\e[0m"
    echo -e "ระบบปฏิบัติการ: $(uname -o) | เคอร์เนล: $(uname -r)"
    echo -e "ระยะเวลาทำงาน: $(uptime -p)"
    df -h / | awk 'NR==2 {print "พื้นที่ฮาร์ดดิสก์ -> รวม: " $2 " | ใช้ไป: " $3 " | เหลือ: " $4}'
    echo -e "─────────────────────────────────────────────────────\n"
}

# [24] ลิงก์ดาวน์โหลด
show_download_links() {
    clear
    echo -e "\e[1;31m ─────────────── ลิงก์โหลดไฟล์ CONFIG (.ovpn) ───────────────\e[0m"
    if [ -d "/var/www/html/download" ] && [ "$(ls -A /var/www/html/download 2>/dev/null)" ]; then
        for file in /var/www/html/download/*.ovpn; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                echo -e "• User: \e[1;32m${filename%.*}\e[0m -> \e[1;34mhttp://$MYIP/download/$filename\e[0m"
            fi
        done
    else
        echo -e "\e[1;31mยังไม่มีไฟล์ Config ใดๆ อยู่บนหน้าเว็บ\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────────────\n"
}

# 4. ฟังก์ชันแสดงหน้าต่างเมนูหลัก
show_menu() {
    clear
    local ram_total=$(free -m | awk '/^Mem:/{print $2}')
    local ram_used=$(free -m | awk '/^Mem:/{print $3}')
    local total_users=$(ls -1 /var/www/html/download/*.ovpn 2>/dev/null | wc -l)

    echo -e "\e[1;31m ─────────────── K TH-VPN FREE SCRIPT ───────────────\e[0m"
    echo -e "OS: Linux VPS        RAM: ${ram_total}M (ใช้ไป: ${ram_used}M)   Core: $(nproc)"
    echo -e "─────────────────────────────────────────────────────"
    echo -e "IP: $MYIP   |   ไฟล์ Config ในระบบทั้งหมด: $total_users บัญชี"
    echo -e "─────────────────────────────────────────────────────"
    echo -e " [01] • สร้างชื่อผู้ใช้          [11] • เทสสปีดความเร็ว"
    echo -e " [02] • สร้างบัญชี ทดลอง        [12] • ใส่เครดิต"
    echo -e " [03] • ลบ ผู้ใช้               [13] • ดาต้า"
    echo -e " [04] • เช็คคนออนไลน์           [14] • เพิ่มประสิทธิภาพ"
    echo -e " [05] • เปลี่ยนวันหมดอายุ        [15] • สำรองผู้ใช้และคืนค่า"
    echo -e " [06] • เปลี่ยนขีด จำกัดเชื่อมต่อ   [16] • จำกัดการเชื่อมต่อ"
    echo -e " [07] • เปลี่ยนรหัสผ่าน          [17] • VPN ที่ไม่ดี"
    echo -e " [08] • ลบผู้ใช้หมดอายุแล้ว       [18] • ข้อมูล VPS"
    echo -e " [09] • เช็คบัญชีทั้งหมด          [24] • ดาวน์โหลด config.ovpn"
    echo -e " [10] • ตั้งค่าระบบต่างๆ          [00] • ออกจากระบบสคริปต์"
    echo -e "─────────────────────────────────────────────────────"
}

# 5. ลูปการทำงานหลัก
while true; do
    show_menu
    echo -n "Choose a menu ?? : "
    read -r choice
    
    # เคลียร์ค่าว่างแฝงและตัดอักษรแปลกปลอมออกให้หมด
    choice=$(echo "$choice" | tr -d '\r' | tr -d ' ' | tr -d '\n')

    case "$choice" in
        1|01)
            engine_add_user
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        3|03)
            engine_delete_user
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        4|04)
            check_online
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        10)
            system_settings
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        11)
            test_speed
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        18)
            show_vps_info
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        24)
            show_download_links
            echo -n "กด Enter เพื่อกลับหน้าหลัก..."; read -r
            ;;
        0|00)
            echo "ปิดสคริปต์เรียบร้อยครับ!"
            exit 0
            ;;
        *)
            echo -e "\n\e[1;31m[!] ปุ่ม '$choice' ยังไม่ได้ต่อระบบ หรือกดเลขไม่ถูกต้อง ลองใหม่อีกครั้ง\e[0m"
            sleep 2
            ;;
    esac
done
