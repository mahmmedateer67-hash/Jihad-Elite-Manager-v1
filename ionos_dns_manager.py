#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import json
import sys
import os

# --- إعدادات IONOS API ---
# Base URL: https://api.hosting.ionos.com/dns
# Authentication: X-API-Key
BASE_URL = "https://api.hosting.ionos.com/dns/v1/zones"
ZONE_ID = "13e0b11c-0726-11f1-8880-0a5864440f43"
import os
API_KEY = os.getenv("IONOS_API_KEY") # قراءة المفتاح من متغير البيئة
if not API_KEY:
    print(f"{RED}❌ خطأ: لم يتم تعيين متغير البيئة IONOS_API_KEY. يرجى تعيينه قبل التشغيل.{RESET}")
    sys.exit(1)

HEADERS = {
    "X-API-Key": API_KEY,
    "Content-Type": "application/json"
}

# الألوان للتنسيق
GREEN = '\033[38;5;46m'
RED = '\033[38;5;196m'
YELLOW = '\033[38;5;226m'
BLUE = '\033[38;5;39m'
RESET = '\033[0m'

def get_all_records():
    """
    مفتاح الـ Record ID: لا يمكن حذف أي سجل بالاسم فقط؛ يجب عمل GET أولاً لجلب الـ id.
    هذه الوظيفة تجلب جميع السجلات لاستخراج الـ id.
    """
    url = f"{BASE_URL}/{ZONE_ID}/records"
    try:
        response = requests.get(url, headers=HEADERS)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"{RED}❌ خطأ في جلب السجلات: {e}{RESET}")
        return None

def create_jihad_records(server_ip):
    """
    مفتاح الـ Array (المصفوفة): واجهة برمجة IONOS تتوقع قائمة [] حتى لو كان سجلاً واحداً.
    مفتاح الـ TTL: تم ضبطه على 3600 لضمان استجابة سريعة.
    مفتاح الـ FQDN: استخدام الاسم الكامل للنطاق.
    """
    url = f"{BASE_URL}/{ZONE_ID}/records"
    
    # بناء البيانات المطلوبة (سجل A وسجل NS)
    records_data = [
        {
            "name": "jihad.02iuk.shop",
            "type": "A",
            "content": server_ip,
            "ttl": 3600
        },
        {
            "name": "tun.jihad.02iuk.shop",
            "type": "NS",
            "content": "jihad.02iuk.shop",
            "ttl": 3600
        }
    ]
    
    try:
        print(f"{BLUE}⚙️ جاري إنشاء السجلات في IONOS...{RESET}")
        response = requests.post(url, headers=HEADERS, data=json.dumps(records_data))
        if response.status_code == 201 or response.status_code == 200:
            print(f"{GREEN}✅ تم إنشاء السجلات بنجاح!{RESET}")
            print(f"   - A Record: jihad.02iuk.shop -> {server_ip}")
            print(f"   - NS Record: tun.jihad.02iuk.shop -> jihad.02iuk.shop")
        else:
            print(f"{RED}❌ فشل الإنشاء. كود الحالة: {response.status_code}{RESET}")
            print(response.text)
    except Exception as e:
        print(f"{RED}❌ خطأ تقني: {e}{RESET}")

def smart_delete_jihad_records():
    """
    وظيفة حذف ذكية (DELETE): تقوم ببحث تلقائي عن السجلات وتستخرج الـ id ثم تحذفها.
    """
    print(f"{BLUE}🔍 جاري البحث عن السجلات لحذفها ذكياً...{RESET}")
    records = get_all_records()
    if not records:
        return

    target_names = ["jihad.02iuk.shop", "tun.jihad.02iuk.shop"]
    deleted_count = 0

    for record in records:
        if record.get("name") in target_names:
            record_id = record.get("id")
            record_name = record.get("name")
            delete_url = f"{BASE_URL}/{ZONE_ID}/records/{record_id}"
            try:
                res = requests.delete(delete_url, headers=HEADERS)
                if res.status_code == 204 or res.status_code == 200:
                    print(f"{GREEN}✅ تم حذف السجل: {record_name} (ID: {record_id}){RESET}")
                    deleted_count += 1
                else:
                    print(f"{RED}❌ فشل حذف {record_name}. كود: {res.status_code}{RESET}")
            except Exception as e:
                print(f"{RED}❌ خطأ أثناء الحذف: {e}{RESET}")
    
    if deleted_count == 0:
        print(f"{YELLOW}⚠️ لم يتم العثور على سجلات مطابقة لحذفها.{RESET}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        action = sys.argv[1]
        if action == "create":
            if len(sys.argv) > 2:
                server_ip = sys.argv[2]
                create_jihad_records(server_ip)
            else:
                print(f"{RED}❌ خطأ: يجب توفير IP السيرفر لإنشاء السجلات.{RESET}")
        elif action == "delete":
            smart_delete_jihad_records()
        elif action == "main_menu":
            # Fallback to interactive menu if called explicitly
            pass
        else:
            print(f"{RED}❌ أمر غير معروف: {action}{RESET}")
    else:
        # If no arguments, show interactive menu
        pass

def main_menu():
    while True:
        print(f"\n{BLUE}═══════════════[ 🌐 IONOS DNS MANAGER ]═══════════════{RESET}")
        print(f"  {GREEN}[1]{RESET} جلب وعرض جميع سجلات DNS")
        print(f"  {GREEN}[2]{RESET} إنشاء سجلات Jihad (A & NS)")
        print(f"  {GREEN}[3]{RESET} حذف ذكي لسجلات Jihad")
        print(f"  {RED}[0]{RESET} العودة للقائمة الرئيسية")
        print(f"{BLUE}──────────────────────────────────────────────────────{RESET}")
        
        choice = input(f"{YELLOW}👉 اختر خياراً: {RESET}")

        if choice == '1':
            records = get_all_records()
            if records:
                print(f"\n{WHITE}قائمة السجلات الحالية:{RESET}")
                for r in records:
                    print(f" - {r['name']} [{r['type']}] -> {r['content']} (ID: {r['id']})")
        elif choice == '2':
            ip = input(f"{YELLOW}👉 أدخل IP السيرفر: {RESET}")
            if ip:
                create_jihad_records(ip)
        elif choice == '3':
            smart_delete_jihad_records()
        elif choice == '0':
            break
        else:
            print(f"{RED}❌ خيار غير صحيح!{RESET}")

    main_menu()
