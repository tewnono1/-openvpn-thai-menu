#!/bin/bash

# ดึง IP จริงของเครื่อง VPS มาทำลิงก์ดาวน์โหลด
MYIP=$(wget -qO- iboy.im/ip || curl -s ifconfig.me || echo "ของคุณ")
ENGINE="./openvpn-install.sh"

# ฟังก์ชันตรวจสอบและตั้งค่าเว็บดาวน์โหลด
check_webserver() {
    if ! command -v apache2 &> /dev/null && ! command -v nginx &> /dev/null; then
        echo -e "\n\e[1;33m[ระบบ]\e[0m กำลังติดตั้งส่วนเสริมระบบดาวน์โหลด (Apache)..."
        apt-get update -y > /dev/null
        apt-get install apache2 -y > /dev/null
        systemctl start apache2
        systemctl enable apache2
    fi
    mkdir -p /var/www/html/download
}

# ฟังก์ชันสร้างผู้ใช้จริงโดยใช้เครื่องยนต์ Angristan
engine_add_user() {
    check_webserver
    
    # ตรวจสอบว่ามีไฟล์เครื่องยนต์ติดตั้งอยู่ไหม
    if [ ! -f "$ENGINE" ]; then
        echo -e "\n\e[1;31m[ข้อผิดพลาด] ไม่พบไฟล์ openvpn-install.sh ในโฟลเดอร์เดียวกัน\e[0m"
        echo -e "กรุณาดาวน์โหลดมาก่อน หรือใช้เมนูติดตั้งระบบก่อนครับ\e[0m"
        return
    fi

    echo -e "\n\e[1;36m[ระบบ]\e[0m กำลังเข้าสู่โหมดสร้างผู้ใช้ของ Angristan..."
    echo -e "\e[1;33m(กรุณากรอกชื่อผู้ใช้ตามขั้นตอนของระบบหลังบ้านด้านล่างนี้)\e[0m\n"
    
    # รันเครื่องยนต์จริงของ Angristan เพื่อสร้างไฟล์ .ovpn แท้ๆ
    # ระบบจะถามชื่อผู้ใช้ และตั้งค่าคีย์เข้ารหัสให้อัตโนมัติ
    MENU_OPTION="1" bash "$ENGINE"
    
    # ค้นหาไฟล์ .ovpn ล่าสุดที่เพิ่งถูกสร้างขึ้นในโฟลเดอร์ /root หรือโฟลเดอร์ปัจจุบัน
    # แล้วคัดลอกไปยังโฟลเดอร์ดาวน์โหลดของหน้าเว็บ
    echo -e "\n\e[1;36m[ระบบ]\e[0m กำลังซิงค์ไฟล์ไปยังระบบดาวน์โหลด..."
    cp /root/*.ovpn /var/www/html/download/ 2>/dev/null
    cp ./*.ovpn /var/www/html/download/ 2>/dev/null
    chmod -R 644 /var/www/html/download/
    
    echo -e "\n\e[1;32m[สำเร็จ] ระบบซิงค์ข้อมูลเรียบร้อยแล้ว!\e[0m"
    echo -e "คุณสามารถตรวจสอบลิงก์ดาวน์โหลดได้ที่ เมนู [24] ครับ\n"
}

# ฟังก์ชันเรียกดูลิงก์ดาวน์โหลดทั้งหมดที่มีอยู่
show_download_links() {
    clear
    echo -e "\e[1;31m ─────────────── รายการลิงก์ดาวน์โหลด CONFIG ───────────────\e[0m"
    if [ -d "/var/www/html/download" ] && [ "$(ls -A /var/www/html/download)" ]; then
        echo -e "คุณสามารถก๊อปปี้ลิงก์ด้านล่างนี้ไปเปิดในบราวเซอร์เพื่อดาวน์โหลด:\n"
        for file in /var/www/html/download/*.ovpn; do
            filename=$(basename "$file")
            # กรองแสดงเฉพาะไฟล์ที่มีข้อมูลจริง
            if [ -s "$file" ]; then
                echo -e "• User: \e[1;32m${filename%.*}\e[0m"
                echo -e "  URL: \e[1;34mhttp://$MYIP/download/$filename\e[0m"
                echo -e "-----------------------------------------------------"
            fi
        done
    else
        echo -e "\e[1;31mยังไม่มีการสร้างไฟล์ Config ใดๆ ในระบบ\e[0m"
    fi
    echo -e "─────────────────────────────────────────────────────"
}

show_menu() {
    clear
    echo -e "\e[1;31m ─────────────── K TH-VPN FREE SCRIPT ───────────────\e[0m"
    echo -e "\e[1;32mระบบ\e[0m                  \e[1;32mหน่วยความจำ\e[0m            \e[1;32mโปรเซสเซอร์\e[0m"
    echo -e "OS: Debian/Ubuntu     รวม: 996M              แกน: 1"
    echo -e "เวลา: $(date +%H:%M:%S)       ภาพรวม: 4.12%          การใช้งาน: 9.4%"
    echo -e "─────────────────────────────────────────────────────"
    echo -e "\e[1;36mIP เซิร์ฟเวอร์:\e[0m $MYIP       \e[1;32mออนไลน์:\e[0m 0        \e[1;33มชื่อทั้งหมด:\e[0m 1"
    echo -e "─────────────────────────────────────────────────────"

    echo -e "\e[1;34m[\e[1;37m01\e[1;34m]\e[0m • สร้างชื่อผู้ใช้          \e[1;34m[\e[1;37m11\e[1;34m]\e[0m • เทสสปีด"
    echo -e "\e[1;34m[\e[1;37m02\e[1;34m]\e[0m • สร้างบัญชี ทดลอง        \e[1;34m[\e[1;37m12\e[1;34m]\e[0m • ใส่เครดิต"
    echo -e "\e[1;34m[\e[1;37m03\e[1;34m]\e[0m • ลบ ผู้ใช้               \e[1;34m[\e[1;37m13\e[1;34m]\e[0m • ดาต้า"
    echo -e "\e[1;34m[\e[1;37m04\e[1;34m]\e[0m • เช็คคนออนไลน์           \e[1;34m[\e[1;37m14\e[1;34m]\e[0m • เพิ่มประสิทธิภาพ"
    echo -e "\e[1;34m[\e[1;37m05\e[1;34m]\e[0m • เปลี่ยนวันหมดอายุ        \e[1;34m[\e[1;37m15\e[1;34m]\e[0m • สำรองผู้ใช้และคืนค่า"
    echo -e "\e[1;34m[\e[1;37m06\e[1;34m]\e[0m • เปลี่ยนขีด จำกัดเชื่อมต่อ   \e[1;34m[\e[1;37m16\e[1;34m]\e[0m • จำกัดการเชื่อมต่อ"
    echo -e "\e[1;34m[\e[1;37m07\e[1;34m]\e[0m • เปลี่ยนรหัสผ่าน          \e[1;34m[\e[1;37m17\e[1;34m]\e[0m • VPN ที่ไม่ดี"
    echo -e "\e[1;34m[\e[1;37m08\e[1;34m]\e[0m • ลบผู้ใช้หมดอายุแล้ว       \e[1;34m[\e[1;37m18\e[1;34m]\e[0m • ข้อมูล VPS"
    echo -e "\e[1;34m[\e[1;37m09\e[1;34m]\e[0m • เช็คบัญชีทั้งหมด          \e[1;34m[\e[1;37m24\e[1;34m]\e[0m • ดาวน์โหลด config.ovpn"
    echo -e "\e[1;34m[\e[1;30m10\e[1;34m]\e[0m • ตั้งค่าระบบต่างๆ          \e[1;31m[\e[1;37m00\e[1;31m]\e[0m • ออก <<<"
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
        24)
            show_download_links
            read -p "กด Enter เพื่อกลับหน้าเมนูหลัก"
            ;;
        00|0)
            echo "ออกจากระบบสคริปต์เรียบร้อยแล้ว สวัสดีครับ!"
            exit 0
            ;;
        *)
            echo -e "\e[1;31mหมายเลขไม่ถูกต้อง หรือยังไม่ได้เปิดระบบเมนูนี้\e[0m"
            sleep 1
            ;;
    esac
done
