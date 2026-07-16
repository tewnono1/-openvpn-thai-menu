#!/bin/bash

# ตรวจสอบสิทธิ์ Root
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;31m[ข้อผิดพลาด] กรุณารันด้วยสิทธิ์ Root (sudo -i)\e[0m"
    exit 1
fi

MYIP=$(wget -qO- iboy.im/ip || curl -s ifconfig.me || echo "127.0.0.1")
ENGINE="./openvpn-install.sh"

check_webserver() {
    if ! command -v apache2 &> /dev/null && ! command -v nginx &> /dev/null; then
        apt-get update -y > /dev/null
        apt-get install apache2 -y > /dev/null
        systemctl start apache2 > /dev/null 2>&1
        systemctl enable apache2 > /dev/null 2>&1
    fi
    mkdir -p /var/www/html/download
    chmod -R 755 /var/www/html/download
}

# [01] สร้างชื่อผู้ใช้
engine_add_user() {
    check_webserver
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[!] ไม่พบไฟล์ openvpn-install.sh (กรุณาตรวจสอบว่ามีไฟล์อยู่ในโฟลเดอร์เดียวกัน)\e[0m\n"
        return
    fi
    
    echo -e "\n\e[1;36m[ระบบ]\e[0m เข้าสู่โหมดสร้างผู้ใช้ OpenVPN"
    read -p "ใส่ชื่อผู้ใช้ใหม่ (ภาษาอังกฤษเท่านั้น): " username
    username=$(echo "$username" | tr -d '\r' | tr -d ' ')
    
    if [ -z "$username" ]; then
        echo -e "\e[1;31มชื่อผู้ใช้ห้ามว่าง!\e[0m"
        return
    fi

    # ส่งคำสั่งจำลองการกดเลือกให้ Angristan (1=สร้างชื่อ, ตามด้วยชื่อ, 1=ไม่ใช้รหัส)
    echo -e "1\n$username\n1" | bash "$ENGINE"
    
    # ย้ายไฟล์ไปโฟลเดอร์ดาวน์โหลด
    if [ -f "/root/$username.ovpn" ]; then
        cp "/root/$username.ovpn" /var/www/html/download/
    elif [ -f "./$username.ovpn" ]; then
        cp "./$username.ovpn" /var/www/html/download/
    fi
    chmod -R 644 /var/www/html/download/
    echo -e "\n\e[1;32m[สำเร็จ] สร้างบัญชีและอัปโหลดไฟล์ไปที่เมนู [24] เรียบร้อยแล้ว\e[0m\n"
}

# [03] ลบผู้ใช้
engine_delete_user() {
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[!] ไม่พบไฟล์ openvpn-install.sh\e[0m\n"
        return
    fi
    
    echo -e "\n\e[1;36m[ระบบ]\e[0m เข้าสู่โหมดลบผู้ใช้ OpenVPN"
    read -p "ใส่ชื่อผู้ใช้ที่ต้องการลบ: " username
    username=$(echo "$username" | tr -d '\r' | tr -d ' ')
    
    if [ -z "$username" ]; then
        return
    fi

    # ส่งคำสั่งให้ Angristan (2=ลบชื่อ, ตามด้วยชื่อ, y=ยืนยัน)
    echo -e "2\n$username\ny" | bash "$ENGINE"
    rm -f /var/www/html/download/"$username.ovpn"
    echo -e "\n\e[1;31m[สำเร็จ] ลบสิทธิ์ผู้ใช้ $username ออกจากระบบแล้ว\e[0m\n"
}

# [04] เช็คคนออนไลน์
check_online() {
    echo -e "\n\e[1;32m ─────────────── รายชื่อผู้ใช้งานปัจจุบัน ───────────────\e[0m"
    if [ -f "/var/log/openvpn/status.log" ]; then
        cat /var/log/openvpn/status.log | grep -E "CLIENT_LIST|ROUTING_TABLE" || echo "ไม่มีการเชื่อมต่อ"
    elif [ -f "/var/log/openvpn-status.log" ]; then
        cat /var/log/openvpn-status.log | grep -E "CLIENT_LIST|ROUTING_TABLE" || echo "ไม่มีการเชื่อมต่อ"
    else
        echo -e "\e[1;33m[!] ระบบยังไม่มีการบันทึก Log หรือไม่มีการเชื่อมต่อ\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────────────\n"
}

# [10] ตั้งค่าระบบ
system_settings() {
    clear
    echo -e "\e[1;31m ─────────────── ตั้งค่าระบบ OpenVPN ───────────────\e[0m"
    echo -e "[1] • เช็คสถานะการทำงาน (Status)"
    echo -e "[2] • รีสตาร์ทบริการ (Restart OpenVPN)"
    echo -e "[0] • กลับเมนูหลัก"
    echo -e "─────────────────────────────────────────────────────────────"
    read -p "เลือกเมนูย่อย [0-2]: " sys_choice
    case "$sys_choice" in
        1) systemctl status openvpn@server 2>/dev/null || systemctl status openvpn ;;
        2) systemctl restart openvpn@server 2>/dev/null || systemctl restart openvpn; echo "รีสตาร์ทสำเร็จ" ;;
        *) return ;;
    esac
}

# [11] เทสสปีด
test_speed() {
    echo -e "\n\e[1;36m[ระบบ] กำลังทดสอบความเร็วอินเทอร์เน็ต VPS...\e[0m"
    if ! command -v speedtest-cli &> /dev/null; then
        apt-get update && apt-get install speedtest-cli -y > /dev/null
    fi
    speedtest-cli --share
    echo ""
}

# [18] ข้อมูลเครื่อง VPS
show_vps_info() {
    clear
    echo -e "\e[1;31m ─────────────── ข้อมูลระบบ VPS ───────────────\e[0m"
    echo -e "OS: $(uname -o) | Kernel: $(uname -r)"
    echo -e "ระยะเวลาทำงาน (Uptime): $(uptime -p)"
    echo -e "การใช้พื้นที่ดิสก์:"
    df -h / | awk 'NR==2 {print "  รวม: " $2 " | ใช้ไป: " $3 " | เหลือ: " $4}'
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
        echo -e "\e[1;31mยังไม่มีไฟล์ Config ใดๆ ในระบบดาวน์โหลด\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────────────\n"
}

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
    echo -e " [\e[1;32m01\e[0m] • สร้างชื่อผู้ใช้          [\e[1;32m11\e[0m] • เทสสปีดความเร็ว"
    echo -e " [02] • บัญชีทดลอง (ไม่รองรับ)   [12] • ใส่เครดิต (ไม่รองรับ)"
    echo -e " [\e[1;32m03\e[0m] • ลบ ผู้ใช้               [13] • ดาต้า (ไม่รองรับ)"
    echo -e " [\e[1;32m04\e[0m] • เช็คคนออนไลน์           [14] • เพิ่มประสิทธิภาพ (ไม่รองรับ)"
    echo -e " [05] • เปลี่ยนวันหมดอายุ (ไม่รองรับ) [15] • สำรองผู้ใช้และคืนค่า (ไม่รองรับ)"
    echo -e " [06] • จำกัดเชื่อมต่อ (ไม่รองรับ)    [16] • จำกัดการเชื่อมต่อ (ไม่รองรับ)"
    echo -e " [07] • เปลี่ยนรหัสผ่าน (ไม่รองรับ)    [17] • VPN ที่ไม่ดี (ไม่รองรับ)"
    echo -e " [08] • ลบหมดอายุ (ไม่รองรับ)       [\e[1;32m18\e[0m] • ข้อมูล VPS"
    echo -e " [09] • เช็คบัญชีทั้งหมด             [\e[1;32m24\e[0m] • ดาวน์โหลด config.ovpn"
    echo -e " [\e[1;32m10\e[0m] • ตั้งค่าระบบต่างๆ          [\e[1;31m00\e[0m] • ออกจากระบบสคริปต์"
    echo -e "─────────────────────────────────────────────────────"
}

while true; do
    show_menu
    echo -n "Choose a menu ?? : "
    read -r choice
    choice=$(echo "$choice" | tr -d '\r' | tr -d ' ' | tr -d '\n')

    case "$choice" in
        1|01) engine_add_user; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        3|03) engine_delete_user; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        4|04) check_online; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        10)  system_settings; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        11)  test_speed; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        18)  show_vps_info; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        24)  show_download_links; echo -n "กด Enter เพื่อกลับ..."; read -r ;;
        0|00) echo "ปิดระบบสำเร็จ!"; exit 0 ;;
        *) echo -e "\n\e[1;31m[!] ฟังก์ชันนี้ไม่รองรับบนระบบ Angristan หรือใส่เลขไม่ถูกต้อง\e[0m"; sleep 2 ;;
    esac
done
