#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import threading
from datetime import datetime

from Screens.Screen import Screen
from Screens.MessageBox import MessageBox
from Components.ActionMap import ActionMap
from Components.Label import Label
from Components.Button import Button
from Components.ListBox import ListBox
from Components.Sources.List import List
from enigma import eListboxPythonMultiContent, gFont, RT_HALIGN_LEFT, RT_VALIGN_CENTER
from Plugins.Plugin import PluginDescriptor

class ProcessManager:
    def __init__(self):
        self.processes = {}
        self.lock = threading.Lock()
    
    def start_process(self, script_path):
        try:
            if not os.path.exists(script_path):
                return False, "الملف غير موجود"
            os.chmod(script_path, 0o755)
            with self.lock:
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
                return True, f"✓ تم تشغيل: {script_name}"
        except Exception as e:
            return False, f"✗ خطأ: {str(e)}"
    
    def stop_process(self, script_name):
        try:
            with self.lock:
                if script_name in self.processes:
                    self.processes[script_name]['process'].terminate()
                    del self.processes[script_name]
                    return True, f"✓ تم إيقاف: {script_name}"
            return False, "✗ السكريبت غير مشغل"
        except Exception as e:
            return False, f"✗ خطأ: {str(e)}"
    
    def stop_all(self):
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
        with self.lock:
            return list(self.processes.items())

class FileExplorer:
    def __init__(self, start_path="/media/hdd/"):
        self.current_path = start_path
        self.history = [start_path]
        self.history_index = 0
        self.supported_extensions = ['.py', '.sh']
    
    def get_items(self):
        items = []
        try:
            if not os.path.exists(self.current_path):
                return items
            
            entries = os.listdir(self.current_path)
            entries.sort()
            
            if self.current_path != "/":
                items.append(('..', os.path.dirname(self.current_path), 'back'))
            
            directories = []
            files = []
            
            for entry in entries:
                full_path = os.path.join(self.current_path, entry)
                
                if os.path.isdir(full_path) and not entry.startswith('.'):
                    directories.append((entry, full_path, 'dir'))
                elif os.path.isfile(full_path):
                    ext = os.path.splitext(entry)[1]
                    if ext in self.supported_extensions:
                        files.append((entry, full_path, 'file'))
            
            items.extend(sorted(directories))
            items.extend(sorted(files))
        except Exception as e:
            pass
        
        return items
    
    def navigate_to(self, path):
        if os.path.isdir(path):
            self.current_path = path
            self.history = self.history[:self.history_index + 1]
            self.history.append(path)
            self.history_index = len(self.history) - 1
            return True
        return False
    
    def go_back(self):
        if self.history_index > 0:
            self.history_index -= 1
            self.current_path = self.history[self.history_index]
            return True
        return False

class ClientScriptRunner(Screen):
    skin = """
    <screen name="ClientScriptRunner" position="center,center" size="1280,720" title="مدير السكريبتات">
        <!-- الخلفية -->
        <ePixmap pixmap="/usr/lib/enigma2/python/Plugins/Extensions/ClientScriptRunner/skin/bg.png" position="0,0" size="1280,720" zPosition="-1" />
        
        <!-- العنوان الرئيسي -->
        <widget name="title" position="40,20" size="1200,60" font="Regular;40" foregroundColor="#00ff00" halign="center" valign="center" backgroundColor="#000000" transparent="0" />
        
        <!-- الجانب الأيمن: استعراض الملفات -->
        <widget name="file_label" position="640,85" size="600,30" font="Regular;24" foregroundColor="#00ffff" halign="center" />
        <widget name="file_list" position="640,120" size="600,480" font="Regular;22" itemHeight="45" foregroundColor="#ffffff" backgroundColor="#0a0a0a" transparent="0" />
        
        <!-- شريط المسار الأيمن -->
        <widget name="current_path" position="640,610" size="600,35" font="Regular;18" foregroundColor="#ffff00" backgroundColor="#000000" halign="left" valign="center" />
        
        <!-- الجانب الأيسر: السكريبتات المشغلة -->
        <widget name="process_label" position="40,85" size="580,30" font="Regular;24" foregroundColor="#00ffff" halign="center" />
        <widget name="process_list" position="40,120" size="580,480" font="Regular;20" itemHeight="50" foregroundColor="#ffffff" backgroundColor="#0a0a0a" transparent="0" />
        
        <!-- شريط المعلومات -->
        <widget name="process_info" position="40,610" size="580,35" font="Regular;18" foregroundColor="#ffff00" backgroundColor="#000000" halign="left" valign="center" />
        
        <!-- شريط التعليمات السفلي -->
        <widget name="info_bar" position="20,655" size="1240,50" font="Regular;16" foregroundColor="#00ff00" backgroundColor="#1a1a1a" halign="center" valign="center" />
    </screen>
    """
    
    def __init__(self, session):
        Screen.__init__(self, session)
        self.session = session
        self.process_manager = ProcessManager()
        self.file_explorer = FileExplorer("/media/hdd/")
        
        self["title"] = Label("🎬 مدير تشغيل السكريبتات 🎬")
        self["file_label"] = Label("📁 استعراض الملفات")
        self["current_path"] = Label()
        self["file_list"] = Label()
        self["process_label"] = Label("⚙️ السكريبتات المشغلة")
        self["process_list"] = Label()
        self["process_info"] = Label()
        self["info_bar"] = Label()
        
        self.current_selection = 0
        self.focus_side = 'right'
        self.files_list = []
        self.processes_list = []
        self.update_display()
        
        self["actions"] = ActionMap(
            ["OkCancelActions", "DirectionActions", "ColorActions"],
            {
                "ok": self.on_ok,
                "cancel": self.on_cancel,
                "up": self.on_up,
                "down": self.on_down,
                "left": self.toggle_focus,
                "right": self.toggle_focus,
                "red": self.stop_all_processes,
                "green": self.refresh_display,
                "blue": self.show_help,
            },
            -1
        )
    
    def update_display(self):
        # تحديث قائمة الملفات
        self.files_list = self.file_explorer.get_items()
        file_text = ""
        for i, (name, path, ftype) in enumerate(self.files_list):
            if ftype == 'back':
                icon = "🔙"
            elif ftype == 'dir':
                icon = "📁"
            else:
                icon = "🐍" if name.endswith('.py') else "📄"
            
            prefix = "▶ " if (self.focus_side == 'right' and i == self.current_selection) else "  "
            file_text += f"{prefix}{icon} {name}\n"
        
        self["file_list"].setText(file_text.strip() if file_text else "📭 لا توجد ملفات")
        self["current_path"].setText(f"📍 {self.file_explorer.current_path}")
        
        # تحديث قائمة العمليات
        self.processes_list = self.process_manager.get_processes()
        process_text = ""
        for i, (name, info) in enumerate(self.processes_list):
            prefix = "▶ " if (self.focus_side == 'left' and i == self.current_selection) else "  "
            process_text += f"{prefix}▶️ {name}\n    PID: {info['pid']}\n"
        
        self["process_list"].setText(process_text.strip() if process_text else "⏹️ لا توجد سكريبتات مشغلة")
        self["process_info"].setText(f"📊 {len(self.processes_list)} عملية مشغلة")
        
        focus_text = "【 الملفات 】" if self.focus_side == 'right' else "【 العمليات 】"
        self["info_bar"].setText(
            f"↑↓ تصفح | OK تشغيل | ←→ تبديل | 🔴 إيقاف الكل | 🟢 تحديث | 🔵 مساعدة | {focus_text}"
        )
    
    def on_ok(self):
        if self.focus_side == 'right' and self.current_selection < len(self.files_list):
            name, path, ftype = self.files_list[self.current_selection]
            
            if ftype == 'back':
                self.file_explorer.go_back()
                self.current_selection = 0
            elif ftype == 'dir':
                self.file_explorer.navigate_to(path)
                self.current_selection = 0
            elif ftype == 'file':
                success, message = self.process_manager.start_process(path)
                self.session.open(MessageBox, message, MessageBox.TYPE_INFO)
            
            self.update_display()
    
    def on_cancel(self):
        self.close()
    
    def on_up(self):
        if self.focus_side == 'right':
            if self.current_selection > 0:
                self.current_selection -= 1
        else:
            if self.current_selection > 0:
                self.current_selection -= 1
        self.update_display()
    
    def on_down(self):
        if self.focus_side == 'right':
            if self.current_selection < len(self.files_list) - 1:
                self.current_selection += 1
        else:
            if self.current_selection < len(self.processes_list) - 1:
                self.current_selection += 1
        self.update_display()
    
    def toggle_focus(self):
        self.focus_side = 'left' if self.focus_side == 'right' else 'right'
        self.current_selection = 0
        self.update_display()
    
    def stop_all_processes(self):
        count = self.process_manager.stop_all()
        msg = f"✓ تم إيقاف {count} سكريبت!" if count > 0 else "⏹️ لا توجد عمليات"
        self.session.open(MessageBox, msg, MessageBox.TYPE_INFO)
        self.update_display()
    
    def refresh_display(self):
        self.update_display()
        self.session.open(MessageBox, "✓ تحديث", MessageBox.TYPE_INFO)
    
    def show_help(self):
        help_text = """مدير السكريبتات - ClientScriptRunner

🎮 التحكم:
━━━━━━━━━━━━━━━━━
↑ ↓  تصفح
OK   تشغيل/فتح
← →  تبديل
🔴  إيقاف الكل
🟢  تحديث
🔵  مساعدة
ESC  إغلاق

📝 ملفات مدعومة:
🐍 Python (.py)
📄 Shell (.sh)"""
        self.session.open(MessageBox, help_text, MessageBox.TYPE_INFO)

def main(session, **kwargs):
    session.open(ClientScriptRunner)

def Plugins(path, **kwargs):
    return [PluginDescriptor(
        name="ClientScriptRunner",
        description="مدير السكريبتات المتقدم",
        where=PluginDescriptor.WHERE_EXTENSIONSMENU,
        fnc=main
    )]
