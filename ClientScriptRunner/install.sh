#!/bin/bash

################################################################################
# ClientScriptRunner - سكريبت التثبيت الآلي
# لـ Enigma2 على VU+ Solo2
# Python 3.13.12
################################################################################

# الألوان للطباعة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# الإعدادات
PLUGIN_NAME="ClientScriptRunner"
PLUGIN_PATH="/usr/lib/enigma2/plugins/extensions/$PLUGIN_NAME"
TEMP_DIR="/tmp/$PLUGIN_NAME"
REPO_URL="https://github.com/tigrousad/MexiaHub-Repository.git"

################################################################################
# الدوال المساعدة
################################################################################

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   ClientScriptRunner - سكريبت التثبيت الآلي            ║${NC}"
    echo -e "${BLUE}║   Enigma2 Script Manager for VU+ Solo2                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

################################################################################
# التحقق من المتطلبات
################################################################################

check_requirements() {
    print_info "جاري التحقق من المتطلبات..."
    echo ""
    
    # التحقق من Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 غير مثبت"
        return 1
    fi
    print_success "Python3 مثبت: $(python3 --version)"
    
    # التحقق من صلاحيات المسؤول
    if [ "$EUID" -ne 0 ]; then 
        print_error "يجب تشغيل السكريبت كمسؤول (root)"
        print_info "جرّب: sudo bash install.sh"
        return 1
    fi
    print_success "تم التحقق من صلاحيات المسؤول"
    
    # التحقق من اتصال الإنترنت
    if ! ping -q -c 1 -W 1 8.8.8.8 &>/dev/null; then
        print_warning "قد لا تتمكن من التنزيل بدون إنترنت"
    else
        print_success "اتصال الإنترنت متوفر"
    fi
    
    echo ""
    return 0
}

################################################################################
# إنشاء المجلدات
################################################################################

create_directories() {
    print_info "جاري إنشاء المجلدات..."
    echo ""
    
    # إنشاء مجلد الـ Plugin الرئيسي
    if [ ! -d "$PLUGIN_PATH" ]; then
        mkdir -p "$PLUGIN_PATH" || {
            print_error "فشل إنشاء $PLUGIN_PATH"
            return 1
        }
        print_success "تم إنشاء مجلد $PLUGIN_PATH"
    else
        print_warning "المجلد موجود بالفعل: $PLUGIN_PATH"
    fi
    
    # إنشاء مجلد الصور
    if [ ! -d "$PLUGIN_PATH/skin" ]; then
        mkdir -p "$PLUGIN_PATH/skin" || {
            print_error "فشل إنشاء مجلد الصور"
            return 1
        }
        print_success "تم إنشاء مجلد الصور: $PLUGIN_PATH/skin"
    fi
    
    # إنشاء مجلد السكريبتات
    if [ ! -d "/media/hdd/scripts" ]; then
        mkdir -p "/media/hdd/scripts" || {
            print_warning "تعذر إنشاء /media/hdd/scripts"
        }
        print_success "تم إنشاء مجلد السكريبتات: /media/hdd/scripts"
    fi
    
    echo ""
    return 0
}

################################################################################
# تنزيل الملفات
################################################################################

download_plugin() {
    print_info "جاري تنزيل ملفات الـ Plugin..."
    echo ""
    
    # إنشاء مجلد مؤقت
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR" || return 1
    
    # محاولة استنساخ المستودع
    if git clone --depth 1 "$REPO_URL" . 2>/dev/null; then
        print_success "تم تنزيل المستودع"
    else
        print_warning "فشل استنساخ المستودع، محاولة التنزيل المباشر..."
        return 1
    fi
    
    echo ""
    return 0
}

################################################################################
# نسخ الملفات
################################################################################

copy_files() {
    print_info "جاري نسخ الملفات..."
    echo ""
    
    # البحث عن مجلد ClientScriptRunner
    if [ -d "$TEMP_DIR/ClientScriptRunner" ]; then
        SOURCE_DIR="$TEMP_DIR/ClientScriptRunner"
    else
        print_error "لم يتم العثور على مجلد ClientScriptRunner"
        return 1
    fi
    
    # نسخ ملفات Python
    for file in main.py plugin.py __init__.py; do
        if [ -f "$SOURCE_DIR/$file" ]; then
            cp "$SOURCE_DIR/$file" "$PLUGIN_PATH/" || {
                print_error "فشل نسخ $file"
                return 1
            }
            print_success "تم نسخ: $file"
        fi
    done
    
    # نسخ ملفات التوثيق
    for file in README_AR.md INSTALLATION.md; do
        if [ -f "$SOURCE_DIR/$file" ]; then
            cp "$SOURCE_DIR/$file" "$PLUGIN_PATH/" || {
                print_warning "فشل نسخ $file"
            }
        fi
    done
    
    # نسخ ملفات الصور إن وجدت
    if [ -d "$SOURCE_DIR/skin" ]; then
        cp -r "$SOURCE_DIR/skin"/* "$PLUGIN_PATH/skin/" 2>/dev/null || true
        print_success "تم نسخ ملفات الصور"
    fi
    
    echo ""
    return 0
}

################################################################################
# إنشاء الصور تلقائياً إذا لم تكن موجودة
################################################################################

create_images() {
    print_info "جاري التحقق من ملفات الصور..."
    echo ""
    
    # التحقق من ImageMagick
    if ! command -v convert &> /dev/null; then
        print_warning "ImageMagick غير مثبت، سيتم تثبيته..."
        apt-get update &>/dev/null
        apt-get install -y imagemagick &>/dev/null
    fi
    
    # إنشاء خلفية الواجهة
    if [ ! -f "$PLUGIN_PATH/skin/bg.png" ]; then
        print_info "جاري إنشاء خلفية الواجهة..."
        convert -size 1280x720 xc:'#0a0e27' "$PLUGIN_PATH/skin/bg.png" 2>/dev/null && \
            print_success "تم إنشاء bg.png" || \
            print_warning "فشل إنشاء bg.png"
    else
        print_success "bg.png موجود بالفعل"
    fi
    
    # إنشاء شريط التحديد
    if [ ! -f "$PLUGIN_PATH/skin/selection.png" ]; then
        print_info "جاري إنشاء شريط التحديد..."
        convert -size 600x35 xc:'#1e90ff' "$PLUGIN_PATH/skin/selection.png" 2>/dev/null && \
            print_success "تم إنشاء selection.png" || \
            print_warning "فشل إنشاء selection.png"
    else
        print_success "selection.png موجود بالفعل"
    fi
    
    # إنشاء الأيقونة
    if [ ! -f "$PLUGIN_PATH/icon.png" ]; then
        print_info "جاري إنشاء أيقونة الـ Plugin..."
        convert -size 100x100 xc:'#16a085' \
            -fill white -pointsize 60 -gravity center -annotate +0+0 "▶" \
            "$PLUGIN_PATH/icon.png" 2>/dev/null && \
            print_success "تم إنشاء icon.png" || \
            print_warning "فشل إنشاء icon.png"
    else
        print_success "icon.png موجود بالفعل"
    fi
    
    echo ""
}

################################################################################
# ضبط الصلاحيات
################################################################################

set_permissions() {
    print_info "جاري ضبط الصلاحيات..."
    echo ""
    
    # صلاحيات المجلدات
    chmod 755 "$PLUGIN_PATH" || print_warning "فشل ضبط صلاحيات $PLUGIN_PATH"
    chmod 755 "$PLUGIN_PATH/skin" 2>/dev/null || true
    
    # صلاحيات ملفات Python
    chmod 644 "$PLUGIN_PATH"/*.py 2>/dev/null || true
    chmod 755 "$PLUGIN_PATH/main.py" || print_warning "فشل ضبط صلاحيات main.py"
    
    # صلاحيات مجلد السكريبتات
    chmod 755 "/media/hdd/scripts" 2>/dev/null || true
    
    print_success "تم ضبط جميع الصلاحيات"
    echo ""
}

################################################################################
# إنشاء سكريبتات مثال
################################################################################

create_example_scripts() {
    print_info "جاري إنشاء سكريبتات مثال..."
    echo ""
    
    EXAMPLES_DIR="/media/hdd/scripts"
    
    # مثال Python
    cat > "$EXAMPLES_DIR/example_python.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
مثال على سكريبت Python
ClientScriptRunner Example
"""

import time
import sys

def main():
    print("[ClientScriptRunner] Python Example Started")
    print(f"[ClientScriptRunner] Python Version: {sys.version}")
    
    counter = 0
    while True:
        counter += 1
        print(f"[ClientScriptRunner] Running... Count: {counter}")
        time.sleep(5)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[ClientScriptRunner] Stopped by user")
        sys.exit(0)
EOF
    
    chmod +x "$EXAMPLES_DIR/example_python.py"
    print_success "تم إنشاء: example_python.py"
    
    # مثال Shell
    cat > "$EXAMPLES_DIR/example_shell.sh" << 'EOF'
#!/bin/bash
# مثال على سكريبت Shell
# ClientScriptRunner Example

echo "[ClientScriptRunner] Bash Script Started"
echo "[ClientScriptRunner] Hostname: $(hostname)"

counter=0
while true; do
    counter=$((counter + 1))
    echo "[ClientScriptRunner] Running... Count: $counter - Time: $(date)"
    sleep 5
done
EOF
    
    chmod +x "$EXAMPLES_DIR/example_shell.sh"
    print_success "تم إنشاء: example_shell.sh"
    
    echo ""
}

################################################################################
# إعادة تشغيل Enigma2
################################################################################

restart_enigma2() {
    print_warning "يجب إعادة تشغيل Enigma2 لتفعيل الـ Plugin"
    echo ""
    echo "الخيارات:"
    echo "1) إعادة تشغيل الآن"
    echo "2) إعادة تشغيل لاحقاً"
    echo "3) إغلاق البرنامج (ESC)"
    echo ""
    read -p "اختر خياراً (1/2/3): " choice
    
    case $choice in
        1)
            print_info "جاري إعادة تشغيل Enigma2..."
            /etc/init.d/enigma2 restart
            ;;
        2)
            print_info "تذكر: ستحتاج إلى إعادة التشغيل لاحقاً"
            ;;
        *)
            print_info "تم الإلغاء"
            ;;
    esac
}

################################################################################
# التحقق من التثبيت
################################################################################

verify_installation() {
    print_info "جاري التحقق من التثبيت..."
    echo ""
    
    local errors=0
    
    # التحقق من المجلد
    if [ -d "$PLUGIN_PATH" ]; then
        print_success "مجلد الـ Plugin موجود"
    else
        print_error "مجلد الـ Plugin غير موجود"
        errors=$((errors + 1))
    fi
    
    # التحقق من الملفات الأساسية
    for file in main.py plugin.py __init__.py; do
        if [ -f "$PLUGIN_PATH/$file" ]; then
            print_success "ملف $file موجود"
        else
            print_error "ملف $file غير موجود"
            errors=$((errors + 1))
        fi
    done
    
    # التحقق من الصور
    if [ -f "$PLUGIN_PATH/skin/bg.png" ]; then
        print_success "ملف bg.png موجود"
    else
        print_warning "ملف bg.png غير موجود"
    fi
    
    # التحقق من السكريبتات المثال
    if [ -f "/media/hdd/scripts/example_python.py" ]; then
        print_success "السكريبت المثال موجود"
    else
        print_warning "السكريبت المثال غير موجود"
    fi
    
    echo ""
    if [ $errors -eq 0 ]; then
        print_success "التثبيت نجح! ✓"
        return 0
    else
        print_error "حدثت $errors أخطاء أثناء التثبيت"
        return 1
    fi
}

################################################################################
# عرض الملخص النهائي
################################################################################

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              ملخص التثبيت - Installation Summary       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}معلومات التثبيت:${NC}"
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│ Plugin Name: ClientScriptRunner"
    echo "│ Plugin Path: $PLUGIN_PATH"
    echo "│ Python Version: $(python3 --version)"
    echo "│ Enigma2 Device: VU+ Solo2"
    echo "│ Installation Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "└─────────────────────────────────────────────────────┘"
    echo ""
    
    echo -e "${GREEN}الملفات المثبتة:${NC}"
    ls -lh "$PLUGIN_PATH"/ | grep -v "^d" | awk '{print "  • " $9 " (" $5 ")"}'
    echo ""
    
    echo -e "${GREEN}كيفية الاستخدام:${NC}"
    echo "  1. اذهب إلى: المرئيات → الإضافات"
    echo "  2. ابحث عن: ClientScriptRunner"
    echo "  3. اضغط: OK للدخول"
    echo "  4. استخدم الأزرار:"
    echo "     ↑↓ = التصفح"
    echo "     OK = فتح/تشغيل"
    echo "     ← → = التبديل"
    echo "     🔴 = إيقاف الكل"
    echo "     🟢 = تحديث"
    echo "     🔵 = مساعدة"
    echo ""
    
    echo -e "${GREEN}الملفات التوثيقية:${NC}"
    echo "  • README_AR.md - دليل شامل بالعربية"
    echo "  • INSTALLATION.md - دليل التثبيت التفصيلي"
    echo ""
    
    echo -e "${YELLOW}النقاط المهمة:${NC}"
    echo "  ⚠ تأكد من إعادة تشغيل Enigma2"
    echo "  ⚠ ضع السكريبتات في: /media/hdd/scripts/"
    echo "  ⚠ تأكد من صلاحيات التنفيذ للسكريبتات"
    echo ""
}

################################################################################
# عرض الأخطاء
################################################################################

print_troubleshooting() {
    echo -e "${YELLOW}استكشاف الأخطاء:${NC}"
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│ إذا لم يظهر الـ Plugin:"
    echo "│  • أعد تشغيل Enigma2"
    echo "│  • تحقق من المسار: $PLUGIN_PATH"
    echo "│  • تحقق من الصلاحيات: chmod 755 $PLUGIN_PATH"
    echo ""
    echo "│ إذا لم تعمل السكريبتات:"
    echo "│  • جعلها قابلة للتنفيذ: chmod +x /path/to/script.py"
    echo "│  • تحقق من رأس الملف: #!/usr/bin/env python3"
    echo "│  • جرّب تشغيل يدوي: /path/to/script.py"
    echo "└─────────────────────────────────────────────────────┘"
    echo ""
}

################################################################################
# البرنامج الرئيسي
################################################################################

main() {
    print_header
    
    # التحقق من المتطلبات
    check_requirements || exit 1
    
    # إنشاء المجلدات
    create_directories || exit 1
    
    # تنزيل الملفات
    if ! download_plugin; then
        print_warning "لم يتم التنزيل من الإنترنت، سيتم البحث عن الملفات محلياً..."
        if [ ! -d "ClientScriptRunner" ]; then
            print_error "لم يتم العثور على ملفات الـ Plugin"
            exit 1
        fi
    fi
    
    # نسخ الملفات
    copy_files || exit 1
    
    # إنشاء الصور
    create_images
    
    # ضبط الصلاحيات
    set_permissions
    
    # إنشاء سكريبتات مثال
    create_example_scripts
    
    # التحقق من التثبيت
    verify_installation
    
    # عرض الملخص
    print_summary
    
    # عرض معلومات استكشاف الأخطاء
    print_troubleshooting
    
    # إعادة التشغيل
    restart_enigma2
    
    print_success "انتهى التثبيت! شكراً لاستخدامك ClientScriptRunner 🎉"
}

# تشغيل البرنامج
main "$@"
