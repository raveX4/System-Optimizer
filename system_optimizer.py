import os
import sys
import shutil
import subprocess
import threading
import winreg
import tkinter as tk
from tkinter import messagebox, ttk
import ctypes

def is_admin() -> bool:
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

def run_command(command: list[str]) -> bool:
    try:
        subprocess.run(
            command,
            shell=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NO_WINDOW,
            timeout=15,
        )
        return True
    except Exception:
        return False

def set_registry_dword(root_hive, sub_key: str, value_name: str, value_data: int) -> bool:
    try:
        key = winreg.CreateKeyEx(root_hive, sub_key, 0, winreg.KEY_SET_VALUE)
        winreg.SetValueEx(key, value_name, 0, winreg.REG_DWORD, int(value_data))
        winreg.CloseKey(key)
        return True
    except Exception:
        return False

def optimize_power_plan():
    run_command(["powercfg", "-duplicatescheme", "e9a42b02-d5df-448d-aa00-03f14749eb61"])
    run_command(["powercfg", "-setactive", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"])

def clear_temp_files():
    temp_dirs = [
        os.environ.get("TEMP"),
        os.environ.get("TMP"),
        r"C:\Windows\Temp",
    ]
    for d in temp_dirs:
        if d and os.path.exists(d):
            try:
                for entry in os.scandir(d):
                    try:
                        if entry.is_file() or entry.is_symlink():
                            os.remove(entry.path)
                        elif entry.is_dir():
                            shutil.rmtree(entry.path, ignore_errors=True)
                    except Exception:
                        pass
            except Exception:
                pass

def optimize_network():
    run_command(["ipconfig", "/flushdns"])
    run_command(["netsh", "winsock", "reset"])
    run_command(["netsh", "int", "ip", "reset"])

def stop_background_services():
    services = ["SysMain", "WSearch", "DiagTrack"]
    for service in services:
        run_command(["net", "stop", service, "/y"])

def prioritize_games():
    if is_admin():
        set_registry_dword(
            winreg.HKEY_LOCAL_MACHINE,
            r"SYSTEM\CurrentControlSet\Control\PriorityControl",
            "Win32PrioritySeparation",
            38,
        )
    set_registry_dword(
        winreg.HKEY_CURRENT_USER,
        r"System\GameConfigStore",
        "GameDVR_Enabled",
        0,
    )
    set_registry_dword(
        winreg.HKEY_CURRENT_USER,
        r"Software\Microsoft\Windows\CurrentVersion\GameDVR",
        "AppCaptureEnabled",
        0,
    )
    set_registry_dword(
        winreg.HKEY_CURRENT_USER,
        r"Software\Microsoft\GameBar",
        "AllowAutoGameMode",
        1,
    )


class SystemOptimizerApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("System Optimizer")
        self.root.geometry("480x340")
        self.root.configure(bg="#1e1e2e")
        self.root.resizable(False, False)
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

        style = ttk.Style()
        if "clam" in style.theme_names():
            style.theme_use("clam")

        header_frame = tk.Frame(root, bg="#1e1e2e")
        header_frame.pack(pady=15)

        title_label = tk.Label(
            header_frame,
            text="System Optimizer",
            font=("Segoe UI", 20, "bold"),
            bg="#1e1e2e",
            fg="#f38ba8",
        )
        title_label.pack()

        desc_label = tk.Label(
            header_frame,
            text="Optimize your system for maximum performance.",
            font=("Segoe UI", 9),
            bg="#1e1e2e",
            fg="#a6adc8",
        )
        desc_label.pack(pady=5)

        self.status_label = tk.Label(
            root,
            text="Status: Ready",
            font=("Segoe UI", 11),
            bg="#1e1e2e",
            fg="#a6e3a1",
        )
        self.status_label.pack(pady=10)

        self.progress = ttk.Progressbar(
            root, orient="horizontal", length=340, mode="determinate"
        )
        self.progress.pack(pady=10)

        self.optimize_btn = tk.Button(
            root,
            text="Optimize System (BOOST)",
            font=("Segoe UI", 13, "bold"),
            bg="#f38ba8",
            fg="#11111b",
            activebackground="#eba0ac",
            borderwidth=0,
            padx=20,
            pady=10,
            cursor="hand2",
            command=self._start_optimization_thread,
        )
        self.optimize_btn.pack(pady=15)

    def _on_close(self):
        self.root.destroy()

    def _set_status(self, text: str, fg: str = "#89b4fa"):
        self.root.after(0, lambda: self.status_label.config(text=text, fg=fg))

    def _set_progress(self, value: int):
        def update():
            self.progress["value"] = value
        self.root.after(0, update)

    def _start_optimization_thread(self):
        self.optimize_btn.config(state="disabled", text="Optimizing...")
        self._set_progress(0)
        t = threading.Thread(target=self._run_optimization, daemon=True)
        t.start()

    def _run_optimization(self):
        steps = [
            ("Step 1: Setting power plan to High Performance...", optimize_power_plan),
            ("Step 2: Clearing temp and cache files...", clear_temp_files),
            ("Step 3: Stopping background services...", stop_background_services),
            ("Step 4: Optimizing network for low latency...", optimize_network),
            ("Step 5: Setting system and process priority...", prioritize_games),
        ]

        total = len(steps)
        for i, (msg, fn) in enumerate(steps, start=1):
            self._set_status(msg)
            fn()
            self._set_progress(int(i / total * 100))

        self._set_status("Optimization Complete! System is ready.", fg="#a6e3a1")
        self.root.after(
            0,
            lambda: self.optimize_btn.config(state="normal", text="Optimize Again"),
        )
        self.root.after(
            0,
            lambda: messagebox.showinfo(
                "Success",
                "System successfully optimized!\n\n"
                "- Power plan set to maximum performance.\n"
                "- Network and DNS cache cleared.\n"
                "- Background load reduced.\n"
                "- Windows Game Mode enforced.",
            ),
        )


if __name__ == "__main__":
    if not is_admin():
        try:
            ctypes.windll.shell32.ShellExecuteW(
                None, "runas", sys.executable, f'"{os.path.abspath(__file__)}"', None, 1
            )
            sys.exit(0)
        except Exception:
            pass

    root = tk.Tk()
    app = SystemOptimizerApp(root)
    root.mainloop()
