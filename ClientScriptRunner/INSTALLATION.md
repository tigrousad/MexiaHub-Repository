# 🔧 دليل التثبيت - ClientScriptRunner

## خطوات التثبيت السريعة

### الخطوة 1️⃣: نسخ الملفات
```bash
# اتصل بالجهاز عبر SSH
ssh root@192.168.1.100

# تحقق من أن المجلد موجود
ls -la /usr/lib/enigma2/plugins/extensions/

# إذا لم يكن موجوداً، أنشئه
mkdir -p /usr/lib/enigma2/plugins/extensions/

# انسخ ملفات الـ Plugin
cp -r ClientScriptRunner /usr/lib/enigma2/plugins/extensions/
```

### الخطوة 2️⃣: ضبط الصلاحيات
```bash
# اجعل الملفات قابلة للتنفيذ
chmod 755 /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/
chmod 644 /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/*.py
chmod 755 /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/main.py
```

### الخطوة 3️⃣: إعادة تشغيل Enigma2
```bash
# الطريقة الأولى: من الجهاز
# الضغط على زر المفتاح في الريموت واختيار Restart Enigma2

# أو من الـ SSH
/etc/init.d/enigma2 restart
```

### الخطوة 4️⃣: التحقق من التثبيت
بعد إعادة التشغيل:
- اذهب إلى: **المرئيات** → **الإضافات**
- ابحث عن: **ClientScriptRunner**
- اضغط OK لفتحه

---

## ✅ التحقق من التثبيت الناجح

```bash
# تحقق من وجود المجلد
test -d /usr/lib/enigma2/plugins/extensions/ClientScriptRunner && echo "✓ تم التثبيت بنجاح"

# تحقق من الملفات
ls -la /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/
```

**الناتج المتوقع:**
```
-rw-r--r-- root root main.py
-rw-r--r-- root root plugin.py
-rw-r--r-- root root __init__.py
-rw-r--r-- root root README_AR.md
```

---

## 🖼️ إضافة الصور (اختياري لكن مهم)

### إنشاء مجلد الصور:
```bash
mkdir -p /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/skin/
```

### الصور المطلوبة:

#### 1. `bg.png` (خلفية الواجهة)
استخدم صورة بحجم **1280x720** بألوان:
- لون الخلفية: `#0a0e27` (أسود مزرق)
- لون النصوص: أبيض وأخضر

#### 2. `selection.png` (شريط التحديد)
صورة بحجم **600x35** بلون أزرق: `#1e90ff`

#### 3. `icon.png` (أيقونة الـ Plugin)
صورة مربعة بحجم **100x100** تمثل السكريبتات

---

## 📱 إنشاء صور بسيطة (بدون محرر)

### باستخدام ImageMagick:
```bash
# خلفية الواجهة
convert -size 1280x720 xc:'#0a0e27' /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/skin/bg.png

# شريط التحديد
convert -size 600x35 xc:'#1e90ff' /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/skin/selection.png

# الأيقونة
convert -size 100x100 xc:'#16a085' \
    -fill white -pointsize 60 -gravity center -annotate +0+0 "▶" \
    /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/icon.png
```

---

## 🐛 استكشاف المشاكل

### المشكلة 1: الـ Plugin لا يظهر في القائمة
```bash
# تحقق من الملفات
ls -la /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/

# تحقق من صلاحيات الملفات
chmod 755 /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/main.py

# أعد تشغيل Enigma2
/etc/init.d/enigma2 restart
```

### المشكلة 2: خطأ في Python
```bash
# تحقق من نسخة Python
python3 --version

# تحقق من المكتبات المطلوبة
python3 -c "from Screens.Screen import Screen"
```

### المشكلة 3: السكريبتات لا تعمل
```bash
# تحقق من الصلاحيات
chmod +x /path/to/script.py
chmod +x /path/to/script.sh

# جرّب تشغيل يدوي
/path/to/script.py
```

---

## 🔄 التحديث

للتحديث إلى نسخة جديدة:
```bash
# احذف النسخة القديمة
rm -rf /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/

# انسخ النسخة الجديدة
cp -r ClientScriptRunner /usr/lib/enigma2/plugins/extensions/

# أعد التشغيل
/etc/init.d/enigma2 restart
```

---

## ❌ إلغاء التثبيت

```bash
# احذف المجلد بأكمله
rm -rf /usr/lib/enigma2/plugins/extensions/ClientScriptRunner/

# أعد تشغيل Enigma2
/etc/init.d/enigma2 restart
```

---

## ✨ نصائح إضافية

### تثبيت سكريبتات مثال:
```bash
mkdir -p /media/hdd/scripts/
cd /media/hdd/scripts/

# إنشاء سكريبت Python بسيط
cat > test.py << 'EOF'
#!/usr/bin/env python3
import time
while True:
    print("ClientScriptRunner is working!")
    time.sleep(5)
EOF

chmod +x test.py

# إنشاء سكريبت Shell بسيط
cat > test.sh << 'EOF'
#!/bin/bash
while true; do
    echo "Bash script is running!"
    sleep 5
done
EOF

chmod +x test.sh
```

### إنشاء اختصار في الريموت:
في الملف `/etc/enigma2/settings`:
```bash
# أضف هذا السطر
plugin_clientscriptrunner_autostart=true
```

---

## 📞 الدعم

إذا واجهت مشكلة:
1. تحقق من السجلات: `tail -f /tmp/enigma2.log`
2. جرّب إعادة التشغيل
3. تحقق من الصلاحيات
4. راجع دليل الاستخدام

---

**نتمنى لك تثبيتاً ناجحاً! 🎉**
