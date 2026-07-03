#!/bin/bash

# ClientScriptRunner Installation Script - Correct Path
# Installation path - CORRECT
PLUGIN_PATH="/usr/lib/enigma2/python/Plugins/Extensions/ClientScriptRunner"

echo "Installing ClientScriptRunner..."
echo "Path: $PLUGIN_PATH"

# Create directories
mkdir -p "$PLUGIN_PATH/skin"
mkdir -p "/media/hdd/scripts"

# Main Python File
cat > "$PLUGIN_PATH/main.py" << 'MAINEOF'
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
from enigma import eTimer
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
                return True, f"تم تشغيل: {script_name}"
        except Exception as e:
            return False, str(e)
    
    def stop_process(self, script_name):
        try:
            with self.lock:
                if script_name in self.processes:
                    self.processes[script_name]['process'].terminate()
                    del self.processes[script_name]
                    return True, f"تم إيقاف: {script_name}"
            return False, "السكريبت غير مشغل"
        except Exception as e:
            return False, str(e)
    
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
                items.append({
                    'name': '.. (رجوع)',
                    'path': os.path.dirname(self.current_path),
                    'type': 'back',
                    'icon': '🔙'
                })
            
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
    <screen name="ClientScriptRunner" position="center,center" size="1280,720" title="ClientScriptRunner">
        <widget name="title" position="40,20" size="1200,50" font="Regular;32" foregroundColor="#ffffff" halign="center" />
        <widget name="file_list" position="640,80" size="600,550" font="Regular;18" foregroundColor="#ffffff" backgroundColor="#1a1a2e" />
        <widget name="current_path" position="640,640" size="600,30" font="Regular;14" foregroundColor="#00ff00" backgroundColor="#0f0f1e" />
        <widget name="process_list" position="40,80" size="580,550" font="Regular;16" foregroundColor="#ffffff" backgroundColor="#1a1a2e" />
        <widget name="process_info" position="40,640" size="580,30" font="Regular;14" foregroundColor="#00ff00" backgroundColor="#0f0f1e" />
        <widget name="info_bar" position="40,680" size="1200,30" font="Regular;12" foregroundColor="#ffff00" backgroundColor="#0f0f1e" halign="center" />
    </screen>
    """
    
    def __init__(self, session):
        Screen.__init__(self, session)
        self.session = session
        self.process_manager = ProcessManager()
        self.file_explorer = FileExplorer("/media/hdd/")
        
        self["title"] = Label("🎬 مدير تشغيل السكريبتات - ClientScriptRunner")
        self["current_path"] = Label()
        self["file_list"] = Label()
        self["process_list"] = Label()
        self["process_info"] = Label()
        self["info_bar"] = Label()
        
        self.current_selection = 0
        self.focus_side = 'right'
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
        items = self.file_explorer.get_items()
        file_text = "\n".join([f"{item['icon']} {item['name']}" for item in items])
        self["file_list"].setText(file_text if file_text else "📭 لا توجد ملفات")
        self["current_path"].setText(f"📍 {self.file_explorer.current_path}")
        
        processes = self.process_manager.get_processes()
        if processes:
            process_text = "\n".join([f"▶️ {name} (PID: {info['pid']})" for name, info in processes])
            process_count = len(processes)
        else:
            process_text = "⏹️ لا توجد سكريبتات مشغلة"
            process_count = 0
        
        self["process_list"].setText(process_text)
        self["process_info"].setText(f"📊 {process_count} سكريبت مشغل")
        
        focus_text = "الملفات [→]" if self.focus_side == 'right' else "العمليات [←]"
        self["info_bar"].setText(f"↑↓=تصفح | OK=تشغيل | ←→=تبديل | 🔴=إيقاف | 🟢=تحديث | 🔵=مساعدة | {focus_text}")
    
    def on_ok(self):
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
        self.close()
    
    def on_up(self):
        if self.current_selection > 0:
            self.current_selection -= 1
            self.update_display()
    
    def on_down(self):
        items = self.file_explorer.get_items()
        if self.current_selection < len(items) - 1:
            self.current_selection += 1
        self.update_display()
    
    def toggle_focus(self):
        self.focus_side = 'left' if self.focus_side == 'right' else 'right'
        self.current_selection = 0
        self.update_display()
    
    def stop_all_processes(self):
        count = self.process_manager.stop_all()
        self.session.open(MessageBox, f"تم إيقاف {count} سكريبت", MessageBox.TYPE_INFO)
        self.update_display()
    
    def refresh_display(self):
        self.update_display()
    
    def show_help(self):
        help_text = "ClientScriptRunner\n\n🎮 الأزرار:\n↑↓ تصفح\nOK تشغيل\n←→ تبديل\n🔴 إيقاف الكل\n🟢 تحديث\n🔵 مساعدة"
        self.session.open(MessageBox, help_text, MessageBox.TYPE_INFO)

def main(session, **kwargs):
    session.open(ClientScriptRunner)

def Plugins(path, **kwargs):
    return [PluginDescriptor(
        name="ClientScriptRunner",
        description="مدير السكريبتات",
        where=PluginDescriptor.WHERE_EXTENSIONSMENU,
        fnc=main
    )]
MAINEOF

# Plugin descriptor
cat > "$PLUGIN_PATH/plugin.py" << 'PLUGINEOF'
from Plugins.Plugin import PluginDescriptor
from .main import main

def Plugins(**kwargs):
    return [PluginDescriptor(
        name="ClientScriptRunner",
        description="مدير السكريبتات",
        where=PluginDescriptor.WHERE_EXTENSIONSMENU,
        fnc=main
    )]
PLUGINEOF

# Init file
cat > "$PLUGIN_PATH/__init__.py" << 'INITEOF'
__version__ = "1.0.0"
__author__ = "MexiaHub"
INITEOF

# Set permissions
chmod 755 "$PLUGIN_PATH"
chmod 755 "$PLUGIN_PATH/main.py"
chmod 644 "$PLUGIN_PATH/plugin.py"
chmod 644 "$PLUGIN_PATH/__init__.py"
chmod 755 "/media/hdd/scripts"

# Create example scripts
cat > "/media/hdd/scripts/example.py" << 'EXAMPLEEOF'
#!/usr/bin/env python3
import time
import sys

print("[ClientScriptRunner] Python Script Started")
counter = 0
while True:
    counter += 1
    print(f"[ClientScriptRunner] Running... {counter}")
    time.sleep(5)
EXAMPLEEOF

cat > "/media/hdd/scripts/example.sh" << 'EXAMPLEEOF'
#!/bin/bash
echo "[ClientScriptRunner] Bash Script Started"
counter=0
while true; do
    counter=$((counter + 1))
    echo "[ClientScriptRunner] Running... $counter"
    sleep 5
done
EXAMPLEEOF

chmod +x "/media/hdd/scripts/example.py"
chmod +x "/media/hdd/scripts/example.sh"

echo ""
echo "✓ ClientScriptRunner installed successfully!"
echo "✓ Correct Path: $PLUGIN_PATH"
echo "✓ Scripts: /media/hdd/scripts/"
echo ""
echo "Now restart Enigma2:"
echo "  Command: /etc/init.d/enigma2 restart"
echo "  OR: Menu → System → Restart Enigma2"
echo ""
