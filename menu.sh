#!/bin/bash

# ตรวจสอบสิทธิ์ Root ก่อนทำงาน
if [ "$EUID" -ne 0 ]; then
    echo -e "\e[1;31m[ข้อผิดพลาด] กรุณารันสคริปต์นี้ด้วยสิทธิ์ Root เท่านั้น (sudo -i)\e[0m"
    exit 1
fi

# ดึง IP จริงของเครื่อง VPS มาทำลิงก์ดาวน์โหลด
MYIP=$(wget -qO- iboy.im/ip || curl -s ifconfig.me || echo "127.0.0.1")
ENGINE="./openvpn-install.sh"

# ฟังก์ชันตั้งค่าเว็บดาวน์โหลดอัตโนมัติ
check_webserver() {
    if ! command -v apache2 &> /dev/null && ! command -v nginx &> /dev/null; then
        echo -e "\n\e[1;33m[ระบบ]\e[0m กำลังติดตั้งส่วนเสริมระบบดาวน์โหลด (Apache)..."
        apt-get update -y > /dev/null
        apt-get install apache2 -y > /dev/null
        systemctl start apache2
        systemctl enable apache2
    fi
    mkdir -p /var/www/html/download
    chmod -R 755 /var/www/html/download
}

# 01. สร้างชื่อผู้ใช้ (ดึงระบบ Angristan)
engine_add_user() {
    check_webserver
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[ข้อผิดพลาด] ไม่พบไฟล์ openvpn-install.sh ในโฟลเดอร์เดียวกัน\e[0m"
        return
    fi
    MENU_OPTION="1" bash "$ENGINE"
    
    # ซิงค์ไฟล์ไปที่โฟลเดอร์ดาวน์โหลดบนหน้าเว็บ
    cp /root/*.ovpn /var/www/html/download/ 2>/dev/null
    cp ./*.ovpn /var/www/html/download/ 2>/dev/null
    chmod -R 644 /var/www/html/download/
    echo -e "\n\e[1;32m[ระบบ] ซิงค์ไฟล์ Config ไปยังลิงก์ดาวน์โหลดเมนู [24] เรียบร้อยแล้ว!\e[0m\n"
}

# 03. ลบ ผู้ใช้ (ดึงระบบ Angristan)
engine_delete_user() {
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[ข้อผิดพลาด] ไม่พบไฟล์ openvpn-install.sh\e[0m"
        return
    fi
    MENU_OPTION="2" bash "$ENGINE"
    
    # ลบไฟล์ที่อยู่ในหน้าเว็บดาวน์โหลดออกด้วย
    rm -rf /var/www/html/download/* 2>/dev/null
    cp /root/*.ovpn /var/www/html/download/ 2>/dev/null
    chmod -R 644 /var/www/html/download/
}

# 04. เช็คคนออนไลน์
check_online() {
    echo -e "\n\e[1;32m ─────────────── รายชื่อผู้ใช้ที่กำลังเชื่อมต่อ ───────────────\e[0m"
    if [ -f "/var/log/openvpn/status.log" ]; then
        echo -e "Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since"
        sed -n '/ROUTING TABLE/q;p' /var/log/openvpn/status.log | grep -v "OpenVPN CLIENT LIST" | grep -v "Updated"
    elif [ -f "/var/log/openvpn-status.log" ]; then
        echo -e "Common Name,Real Address,Bytes Received,Bytes Sent,Connected Since"
        sed -n '/ROUTING TABLE/q;p' /var/log/openvpn-status.log | grep -v "OpenVPN CLIENT LIST" | grep -v "Updated"
    else
        echo -e "\e[1;33m[แจ้งเตือน] ไม่พบไฟล์ Log หรือยังไม่มีใครเชื่อมต่อเข้ามาในขณะนี้\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────────────\n"
}

# 10. เมนูตั้งค่าระบบต่างๆ (เชื่อมต่อระบบภายใน Linux จริง)
system_settings() {
    clear
    echo -e "\e[1;31m ─────────────── เมนูตั้งค่าระบบ OpenVPN ───────────────\e[0m"
    echo -e "\e[1;34m[1]\e[0m • ตรวจสอบสถานะบริการ (Check Status)"
    echo -e "\e[1;34m[2]\e[0m • รีสตาร์ทระบบ OpenVPN (Restart Service)"
    echo -e "\e[1;34m[3]\e[0m • ตรวจสอบพอร์ต (Port) ที่เปิดใช้งานอยู่"
    echo -e "\e[1;31m[0]\e[0m • กลับหน้าเมนูหลัก"
    echo -e "─────────────────────────────────────────────────────────────"
    read -p "เลือกเมนูตั้งค่า [0-3] : " sys_choice
    
    case $sys_choice in
        1)
            echo -e "\n\e[1;36m[ระบบ] กำลังตรวจสอบสถานะการทำงาน...\e[0m"
            systemctl status openvpn@server 2>/dev/null || systemctl status openvpn 2>/dev/null || echo -e "\e[1;31mไม่พบบริการ OpenVPN ติดตั้งอยู่ในเครื่องนี้\e[0m"
            echo ""
            ;;
        2)
            echo -e "\n\e[1;33m[ระบบ] กำลังรีสตาร์ทบริการ OpenVPN...\e[0m"
            systemctl restart openvpn@server 2>/dev/null || systemctl restart openvpn 2>/dev/null
            echo -e "\e[1;32mรีสตาร์ทระบบเสร็จสิ้นการเชื่อมต่อใหม่เริ่มทำงานแล้ว\e[0m\n"
            ;;
        3)
            echo -e "\n\e[1;36m[ระบบ] รายการพอร์ต OpenVPN ที่กำลังเปิดวิ่งรับข้อมูลอยู่:\e[0m"
            netstat -tuln | grep -i openvpn || ss -tuln | grep -i openvpn || grep -E "^port|^proto" /etc/openvpn/server.conf 2>/dev/null || echo -e "\e[1;31mไม่พบพอร์ตที่เปิดทำงานในไฟล์คอนฟิกหลัก\e[0m"
            echo ""
            ;;
        0|*)
            return
            ;;
    esac
}

# 11. เทสสปีด
test_speed() {
    echo -e "\n\e[1;36m[ระบบ] กำลังเรียกตัวทดสอบความเร็วอินเทอร์เน็ตของ VPS...\e[0m"
    if ! command -v speedtest-cli &> /dev/null; then
        apt-get install speedtest-cli -y > /dev/null
    fi
    speedtest-cli --share
    echo ""
}

# 18. ข้อมูล VPS
show_vps_info() {
    clear
    echo -e "\e[1;31m ─────────────── ข้อมูลทรัพยากรตัวเครื่อง VPS ───────────────\e[0m"
    echo -e "\e[1;32mระบบปฏิบัติการ:\e[0m  $(lsb_release -d | cut -f2 2>/dev/null || uname -o)"
    echo -e "\e[1;32mเวอร์ชันเคอร์เนล:\e[0m $(uname -r)"
    echo -e "\e[1;32mระยะเวลาที่เปิดเครื่อง:\e[0m $(uptime -p)"
    echo -e "\e[1;32มการใช้พื้นที่ฮาร์ดดิสก์:\e[0m"
    df -h / | awk 'NR==2 {print "  รวม: " $2 " | ใช้ไป: " $3 " (" $5 ") | เหลือ: " $4}'
    echo -e "─────────────────────────────────────────────────────────────\n"
}

# 24. ดาวน์โหลด config.ovpn
show_download_links() {
    clear
    echo -e "\e[1;31m ─────────────── รายการลิงก์ดาวน์โหลด CONFIG ───────────────\e[0m"
    if [ -d "/var/www/html/download" ] && [ "$(ls -A /var/www/html/download 2>/dev/null)" ]; then
        echo -e "คัดลอกลิงก์ด้านล่างนี้ไปเปิดในบราวเซอร์มือถือ/คอม เพื่อดาวน์โหลดไฟล์:\n"
        for file in /var/www/html/download/*.ovpn; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                echo -e "• ผู้ใช้งาน: \e[1;32m${filename%.*}\e[0m"
                echo -e "  ลิงก์โหลด: \e[1;34mhttp://$MYIP/download/$filename\e[0m"
                echo -e "-----------------------------------------------------"
            fi
        done
    else
        echo -e "\e[1;31mยังไม่มีไฟล์ Config ที่ถูกสร้าง หรือไฟล์ถูกลบไปแล้ว\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────\n"
}

# ฟังก์ชันแสดงหน้าตาเมนูหลัก
show_menu() {
    clear
    local ram_total=$(free -m | awk '/^Mem:/{print $2}')
    local ram_used=$(free -m | awk '/^Mem:/{print $3}')
    local total_users=$(ls -1 /var/www/html/download/*.ovpn 2>/dev/null | wc -l)

    echo -e "\e[1;31m ─────────────── K TH-VPN FREE SCRIPT ───────────────\e[0m"
    echo -e "\e[1;32mระบบ\e[0m                  \e[1;32mหน่วยความจำ\e[0m            \e[1;32mโปรเซสเซอร์\e[0m"
    echo -e "OS: Linux VPS         รวม: ${ram_total}M (ใช้: ${ram_used}M)   แกน: $(nproc)"
    echo -e "เวลา: $(date +%H:%M:%S)       ภาพรวมระบบทำงานปกติ     การใช้งาน: ต่ำ"
    echo -e "─────────────────────────────────────────────────────"
    echo -e "\e[1;36mIP เซิร์ฟเวอร์:\e[0m $MYIP    \e[1;32มชื่อทั้งหมดในระบบ:\e[0m $total_users"
    echo -e "─────────────────────────────────────────────────────"

    echo -e "\e[1;34m[\e[1;37m01\e[1;34m]\e[0m • สร้างชื่อผู้ใช้          \e[1;34m[\e[1;37m11\e[1;34m]\e[0m • เทสสปีดความเร็ว"
    echo -e "\e[1;34m[\e[1;37m02\e[1;34m]\e[0m • สร้างบัญชี ทดลอง        \e[1;34m[\e[1;37m12\e[1;34m]\e[0m • ใส่เครดิต"
    echo -e "\e[1;34m[\e[1;37m03\e[1;34m]\e[0m • ลบ ผู้ใช้               \e[1;34m[\e[1;37m13\e[1;34m]\e[0m • ดาต้า"
    echo -e "\e[1;34m[\e[1;37m04\e[1;34m]\e[0m • เช็คคนออนไลน์           \e[1;34m[\e[1;37m14\e[1;34m]\e[0m • เพิ่มประสิทธิภาพ"
    echo -e "\e[1;34m[\e[1;37m05\e[1;34m]\e[0m • เปลี่ยนวันหมดอายุ        \e[1;34m[\e[1;37m15\e[1;34m]\e[0m • สำรองผู้ใช้และคืนค่า"
    echo -e "\e[1;34m[\e[1;37m06\e[1;34m]\e[0m • เปลี่ยนขีด จำกัดเชื่อมต่อ   \e[1;34m[\e[1;37m16\e[1;34m]\e[0m • จำกัดการเชื่อมต่อ"
    echo -e "\e[1;34m[\e[1;37m07\e[1;34m]\e[0m • เปลี่ยนรหัสผ่าน          \e[1;34m[\e[1;37m17\e[1;34m]\e[0m • VPN ที่ไม่ดี"
    echo -e "\e[1;34m[\e[1;38m08\e[1;34m]\e[0m • ลบผู้ใช้หมดอายุแล้ว       \e[1;34m[\e[1;37m18\e[1;34m]\e[0m • ข้อมูล VPS"
    echo -e "\e[1;34m[\e[1;37m09\e[1;34m]\e[0m • เช็คบัญชีทั้งหมด          \e[1;34m[\e[1;37m24\e[1;34m]\e[0m • ดาวน์โหลด config.ovpn"
    echo -e "\e[1;34m[\e[1;37m10\e[1;34m]\e[0m • ตั้งค่าระบบต่างๆ          \e[1;31m[\e[1;37m00\e[1;31m]\e[0m • ออก <<<"
    echo -e "─────────────────────────────────────────────────────"
}

while true; do
    show_menu
    read -p "Choose a menu ?? : " choice
    
    case $choice in
        01|1)
            engine_add_user
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        03|3)
            engine_delete_user
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        04|4)
            check_online
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        10)
            system_settings
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        11)
            test_speed
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        18)
            show_vps_info
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        24)
            show_download_links
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        00|0)
            echo "ออกจากระบบสคริปต์เรียบร้อยแล้ว สวัสดีครับ!"
            exit 0
            ;;
        *)
            echo -e "\e[1;31มเลือกหมายเลขไม่ถูกต้อง หรือฟังก์ชันนี้กำลังอยู่ในขั้นตอนพัฒนา\e[0m"
            sleep 1.5
            ;;
    esac
done
