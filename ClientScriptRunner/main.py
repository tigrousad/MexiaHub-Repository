#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ClientScriptRunner - Plugin for Enigma2
Advanced Script Execution Manager
Author: MexiaHub
Version: 1.0.0
"""

import os
import sys
import subprocess
import threading
from pathlib import Path
from datetime import datetime

from Screens.Screen import Screen
from Screens.MessageBox import MessageBox
from Components.ActionMap import ActionMap
from Components.Label import Label
from Components.Button import Button
from Components.Sources.StaticText import StaticText
from Components.Pixmap import Pixmap
from enigma import eConsoleAppContainer, eListboxPythonMultiContent, gFont
from Tools.Directories import resolveFilename, SCOPE_PLUGINS
from Plugins.Plugin import PluginDescriptor

class ProcessManager:
    """إدارة العمليات المشغلة في الخلفية"""
    def __init__(self):
        self.processes = {}
        self.lock = threading.Lock()
    
    def start_process(self, script_path):
        """تشغيل سكريبت في الخلفية"""
        try:
            if not os.path.exists(script_path):
                return False, "الملف غير موجود"
            
            # جعل الملف قابل للتنفيذ
            os.chmod(script_path, 0o755)
            
            with self.lock:
                # فتح العملية في الخلفية
                process = subprocess.Popen(
                    [script_path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True
                )
                
                script_name = os.path.basename(script_path)
                self.processes[script_name] = {
                    'pid': process.pid,
                    'path': script_path,
                    'start_time': datetime.now(),
                    'process': process
                }
                return True, f"تم تشغيل: {script_name}"
        except Exception as e:
            return False, str(e)
    
    def stop_process(self, script_name):
        """إيقاف عملية معينة"""
        try:
            with self.lock:
                if script_name in self.processes:
                    process = self.processes[script_name]['process']
                    process.terminate()
                    del self.processes[script_name]
                    return True, f"تم إيقاف: {script_name}"
            return False, "السكريبت غير مشغل"
        except Exception as e:
            return False, str(e)
    
    def stop_all(self):
        """إيقاف جميع العمليات"""
        count = 0
        with self.lock:
            for script_name in list(self.processes.keys()):
                try:
                    self.processes[script_name]['process'].terminate()
                    count += 1
                except:
                    pass
            self.processes.clear()
        return count
    
    def get_processes(self):
        """الحصول على قائمة العمليات المشغلة"""
        with self.lock:
            return list(self.processes.items())


class FileExplorer:
    """استعراض الملفات والمجلدات"""
    def __init__(self, start_path="/media/hdd/"):
        self.current_path = start_path
        self.history = [start_path]
        self.history_index = 0
        self.supported_extensions = ['.py', '.sh']
    
    def get_items(self):
        """الحصول على الملفات والمجلدات في المسار الحالي"""
        items = []
        try:
            if not os.path.exists(self.current_path):
                return items
            
            entries = os.listdir(self.current_path)
            entries.sort()
            
            # إضافة زر العودة للخلف إذا لم نكن في الجذر
            if self.current_path != "/":
                items.append({
                    'name': '.. (رجوع)',
                    'path': os.path.dirname(self.current_path),
                    'type': 'back',
                    'icon': '🔙'
                })
            
            # فصل المجلدات والملفات
            directories = []
            files = []
            
            for entry in entries:
                full_path = os.path.join(self.current_path, entry)
                
                if os.path.isdir(full_path):
                    directories.append({
                        'name': entry,
                        'path': full_path,
                        'type': 'dir',
                        'icon': '📁'
                    })
                elif os.path.isfile(full_path):
                    ext = os.path.splitext(entry)[1]
                    if ext in self.supported_extensions:
                        files.append({
                            'name': entry,
                            'path': full_path,
                            'type': 'file',
                            'icon': '🐍' if ext == '.py' else '📄'
                        })
            
            items.extend(directories)
            items.extend(files)
        except Exception as e:
            print(f"خطأ في استعراض الملفات: {e}")
        
        return items
    
    def navigate_to(self, path):
        """الذهاب إلى مسار معين"""
        if os.path.isdir(path):
            self.current_path = path
            self.history = self.history[:self.history_index + 1]
            self.history.append(path)
            self.history_index = len(self.history) - 1
            return True
        return False
    
    def go_back(self):
        """الرجوع للمسار السابق"""
        if self.history_index > 0:
            self.history_index -= 1
            self.current_path = self.history[self.history_index]
            return True
        return False
    
    def go_forward(self):
        """الذهاب للمسار التالي"""
        if self.history_index < len(self.history) - 1:
            self.history_index += 1
            self.current_path = self.history[self.history_index]
            return True
        return False


class ClientScriptRunner(Screen):
    """الواجهة الرئيسية للـ Plugin"""
    
    skin = """
    <screen name="ClientScriptRunner" position="center,center" size="1280,720" title="مدير تشغيل السكريبتات">
        <!-- الخلفية -->
        <ePixmap pixmap="/usr/lib/enigma2/plugins/extensions/ClientScriptRunner/skin/bg.png" position="0,0" size="1280,720" zPosition="-1" />
        
        <!-- العنوان الرئيسي -->
        <widget name="title" position="40,20" size="1200,50" font="Regular;32" foregroundColor="#ffffff" halign="center" valign="center" transparent="1" />
        
        <!-- الجزء الأيمن: استعراض الملفات -->
        <widget name="file_list" position="640,80" size="600,550" font="Regular;18" itemHeight="35" foregroundColor="#ffffff" backgroundColor="#1a1a2e" transparent="0" />
        
        <!-- شريط المسار الأيمن -->
        <widget name="current_path" position="640,640" size="600,30" font="Regular;14" foregroundColor="#00ff00" backgroundColor="#0f0f1e" halign="left" valign="center" transparent="0" />
        
        <!-- الجزء الأيسر: السكريبتات المشغلة -->
        <widget name="process_list" position="40,80" size="580,550" font="Regular;16" itemHeight="40" foregroundColor="#ffffff" backgroundColor="#1a1a2e" transparent="0" />
        
        <!-- شريط المسار الأيسر -->
        <widget name="process_info" position="40,640" size="580,30" font="Regular;14" foregroundColor="#00ff00" backgroundColor="#0f0f1e" halign="left" valign="center" transparent="0" />
        
        <!-- شريط المعلومات السفلي -->
        <widget name="info_bar" position="40,680" size="1200,30" font="Regular;12" foregroundColor="#ffff00" backgroundColor="#0f0f1e" halign="center" valign="center" transparent="0" />
    </screen>
    """
    
    def __init__(self, session):
        Screen.__init__(self, session)
        self.session = session
        
        # تهيئة المديرين
        self.process_manager = ProcessManager()
        self.file_explorer = FileExplorer("/media/hdd/")
        
        # العناصر
        self["title"] = Label("🎬 مدير تشغيل السكريبتات - ClientScriptRunner")
        self["current_path"] = Label()
        self["file_list"] = Label()
        self["process_list"] = Label()
        self["process_info"] = Label()
        self["info_bar"] = Label()
        
        # تحديث الواجهة
        self.current_selection = 0
        self.focus_side = 'right'  # right (ملفات) أو left (عمليات)
        self.update_display()
        
        # إعدادات الأزرار
        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions", "StandardActions"],
            {
                "ok": self.on_ok,
                "cancel": self.on_cancel,
                "up": self.on_up,
                "down": self.on_down,
                "left": self.toggle_focus,
                "right": self.toggle_focus,
                "red": self.stop_all_processes,
                "green": self.refresh_display,
                "yellow": self.toggle_focus,
                "blue": self.show_help,
            },
            -1
        )
    
    def update_display(self):
        """تحديث عرض الواجهة"""
        # تحديث قائمة الملفات
        items = self.file_explorer.get_items()
        file_text = "\n".join([
            f"{item['icon']} {item['name']}" for item in items
        ])
        self["file_list"].setText(file_text if file_text else "📭 لا توجد ملفات")
        self["current_path"].setText(f"📍 {self.file_explorer.current_path}")
        
        # تحديث قائمة العمليات المشغلة
        processes = self.process_manager.get_processes()
        if processes:
            process_text = "\n".join([
                f"▶️ {name} (PID: {info['pid']})" 
                for name, info in processes
            ])
            process_count = len(processes)
        else:
            process_text = "⏹️ لا توجد سكريبتات مشغلة"
            process_count = 0
        
        self["process_list"].setText(process_text)
        self["process_info"].setText(f"📊 {process_count} سكريبت مشغل")
        
        # تحديث شريط المعلومات
        focus_text = "الملفات [→]" if self.focus_side == 'right' else "العمليات [←]"
        self["info_bar"].setText(
            f"🎮 التحكم: ↑↓ = تصفح | OK = فتح/تشغيل | ← → = تبديل | 🔴 = إيقاف الكل | 🟢 = تحديث | 🔵 = مساعدة | التركيز: {focus_text}"
        )
    
    def on_ok(self):
        """زر OK: فتح مجلد أو تشغيل سكريبت"""
        if self.focus_side == 'right':
            items = self.file_explorer.get_items()
            if self.current_selection < len(items):
                item = items[self.current_selection]
                
                if item['type'] == 'back':
                    self.file_explorer.go_back()
                elif item['type'] == 'dir':
                    self.file_explorer.navigate_to(item['path'])
                    self.current_selection = 0
                elif item['type'] == 'file':
                    success, message = self.process_manager.start_process(item['path'])
                    self.session.open(MessageBox, message, MessageBox.TYPE_INFO)
            
            self.update_display()
    
    def on_cancel(self):
        """إغلاق الـ Plugin"""
        self.close()
    
    def on_up(self):
        """التصفح لأعلى"""
        if self.current_selection > 0:
            self.current_selection -= 1
            self.update_display()
    
    def on_down(self):
        """التصفح لأسفل"""
        if self.focus_side == 'right':
            items = self.file_explorer.get_items()
            if self.current_selection < len(items) - 1:
                self.current_selection += 1
        
        self.update_display()
    
    def toggle_focus(self):
        """التبديل بين الجانب الأيمن والأيسر"""
        if self.focus_side == 'right':
            self.focus_side = 'left'
        else:
            self.focus_side = 'right'
        
        self.current_selection = 0
        self.update_display()
    
    def stop_all_processes(self):
        """إيقاف جميع العمليات (الزر الأحمر)"""
        count = self.process_manager.stop_all()
        self.session.open(MessageBox, f"تم إيقاف {count} سكريبت", MessageBox.TYPE_INFO)
        self.update_display()
    
    def refresh_display(self):
        """تحديث الشاشة (الزر الأخضر)"""
        self.update_display()
        self.session.open(MessageBox, "تم التحديث", MessageBox.TYPE_INFO)
    
    def show_help(self):
        """عرض نافذة المساعدة (الزر الأزرق)"""
        help_text = """
مدير تشغيل السكريبتات - الدليل السريع

🎮 الأزرار:
┌─ ↑ ↓ : التصفح بين الملفات والعمليات
├─ OK : فتح مجلد أو تشغيل سكريبت
├─ ← → : التبديل بين الملفات والعمليات
├─ 🔴 : إيقاف جميع السكريبتات المشغلة
├─ 🟢 : تحديث الشاشة
├─ 🔵 : عرض هذه المساعدة
└─ ESC : إغلاق الـ Plugin

📝 الملفات المدعومة:
  • ملفات Python (.py)
  • ملفات Shell (.sh)

⚙️ الميزات:
  ✓ تشغيل السكريبتات في الخلفية
  ✓ عرض جميع العمليات المشغلة
  ✓ إيقاف السكريبتات الفردية
  ✓ إيقاف جميع العمليات دفعة واحدة
  ✓ استعراض ملفات اح��رافي
        """
        self.session.open(MessageBox, help_text, MessageBox.TYPE_INFO)


def main(session, **kwargs):
    """نقطة البداية للـ Plugin"""
    session.open(ClientScriptRunner)


def Plugins(path, **kwargs):
    """تعريف الـ Plugin"""
    return [
        PluginDescriptor(
            name="ClientScriptRunner",
            description="مدير متقدم لتشغيل السكريبتات في الخلفية",
            where=PluginDescriptor.WHERE_EXTENSIONSMENU,
            fnc=main,
            icon="/usr/lib/enigma2/plugins/extensions/ClientScriptRunner/icon.png",
            needsRestart=False
        )
    ]
