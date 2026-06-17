#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import os
import tkinter as tk
from tkinter import ttk
from PIL import Image, ImageTk

# ------------------------------------------------------
# Extraer argumentos
args = sys.argv[1:]

# Valores por defecto
title = "PyYad"
width = 400
height = 400
window_icon = None
button_label = "Ejecutar ...o tipear Enter"

# Filtrar flags conocidos
i = 0
while i < len(args):
    if args[i].startswith("--title="):
        title = args[i].split("=", 1)[1]
        args.pop(i)
        continue
    if args[i] == "--title":
        title = args[i+1]
        args.pop(i); args.pop(i)
        continue
    if args[i].startswith("--width="):
        width = int(args[i].split("=", 1)[1])
        args.pop(i)
        continue
    if args[i].startswith("--height="):
        height = int(args[i].split("=", 1)[1])
        args.pop(i)
        continue
    if args[i].startswith("--window-icon="):
        window_icon = args[i].split("=", 1)[1]
        args.pop(i)
        continue
    if args[i].startswith("--button="):
        button_label = args[i].split("=", 1)[1].split(":")[0]
        args.pop(i)
        continue
    if args[i].startswith("--"):
        args.pop(i)
        continue
    i += 1

# Ahora args solo contiene triples: icono, comando, descripción
rows = []
i = 0
while i + 2 < len(args):
    icon, cmd, desc = args[i], args[i+1], args[i+2]
    rows.append((icon, cmd, desc))
    i += 3

# ------------------------------------------------------
# Crear ventana
root = tk.Tk()
root.title(title)
root.geometry(f"{width}x{height}")

# ---------------- Tema oscuro ----------------
bg_color = "#2e2e2e"
fg_color = "#ffffff"
tree_bg = "#3c3f41"
tree_fg = "#ffffff"
sel_bg = "#505357"
sel_fg = "#ffffff"
btn_bg = "#444444"
btn_fg = "#ffffff"

root.configure(bg=bg_color)

if window_icon and os.path.isfile(window_icon):
    try:
        ico = ImageTk.PhotoImage(Image.open(window_icon).resize((24,24)))
        root.iconphoto(False, ico)
    except:
        pass

# ------------------------------------------------------
# Treeview con iconos usando la columna de árbol (#0)
style = ttk.Style()
style.theme_use("clam")  # necesario para colores personalizados
style.configure("Treeview",
                background=tree_bg,
                foreground=tree_fg,
                fieldbackground=tree_bg,
                rowheight=24)
style.map("Treeview",
          background=[("selected", sel_bg)],
          foreground=[("selected", sel_fg)])

tree = ttk.Treeview(root, columns=("Comando", "Descripcion"), show="tree headings", height=20)
tree.heading("#0", text="")  # columna para iconos
tree.column("#0", width=60, stretch=False)

tree.heading("Comando", text="Comando")
tree.heading("Descripcion", text="Descripcion")
tree.column("Comando", width=150)
tree.column("Descripcion", width=220)
tree.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

# Guardar referencias de iconos para que no se borren
icon_refs = {}

for icon_path, cmd, desc in rows:
    icon_img = None
    icon_path = os.path.expanduser(icon_path)
    if os.path.isfile(icon_path):
        try:
            img = Image.open(icon_path).resize((18, 18), Image.LANCZOS)
            icon_img = ImageTk.PhotoImage(img)
            icon_refs[cmd] = icon_img
        except Exception as e:
            print(f"Error cargando icono {icon_path}: {e}")
    
    # Insertar item usando la columna #0 para el icono
    tree.insert("", tk.END, text="", values=(cmd, desc), image=icon_img)

# ------------------------------------------------------
# Botón Ejecutar
def ejecutar():
    sel = tree.selection()
    if sel:
        val = tree.item(sel[0], "values")[0]  # columna comando
        print(val)
        root.destroy()

btn = tk.Button(root, text=button_label, command=ejecutar,
                bg=btn_bg, fg=btn_fg,
                activebackground=sel_bg, activeforeground=sel_fg)
btn.pack(side=tk.BOTTOM, fill=tk.X, padx=5, pady=5)

# ------------------------------------------------------
# Permitir doble click
tree.bind("<Double-1>", lambda e: ejecutar())
# Permitir Enter sobre selección
tree.bind("<Return>", lambda e: ejecutar())
# Selección con flechas
tree.focus_set()

root.mainloop()

# HOW TO BUILD PyYad (Hyperbola / Arch-like)
#
# 1. Crear directorio de trabajo:
#    cd $HOME
#    mkdir PyYad && cd PyYad
#
# 2. Vincular el script PyYad.py:
#    ln -svf $HOME/monoliths-llm/PyYad.py $HOME/PyYad/
#
# 3. Instalar dependencias de sistema para Tkinter:
#    sudo pacman -S python tk tcl
#    # Asegúrate de que Python tenga soporte _tkinter
#
# 4. (Opcional pero recomendado) Crear un virtualenv:
#    python3 -m venv venv
#    source venv/bin/activate
#    python3 -m pip install --upgrade pip pyinstaller pillow
#    # pillow es necesario si tu PyYad carga iconos PNG
#
# 5. Probar PyYad antes de compilar:
#    python3 PyYad.py
#    # Debe abrir la ventana de la GUI sin errores
#
# 6. Compilar el binario standalone con PyInstaller:
#    pyinstaller --onefile --hidden-import=PIL._tkinter_finder PyYad.py
#
# 7. Resultado del binario:
#    $HOME/PyYad/dist/PyYad
#    # Verificar permisos:
#    chmod +x $HOME/PyYad/dist/PyYad
#
# 8. (Opcional) Hacerlo disponible globalmente:
#    mkdir -p $HOME/bin
#    cp $HOME/PyYad/dist/PyYad $HOME/bin/
#    # Asegúrate de que $HOME/bin esté en tu PATH
#
# 9. (Opcional) Iconos y assets:
#    Si tu PyYad carga PNG u otros archivos, pueden mantenerse en
#    $HOME/monoliths-hm/ o incluirse en el binario usando PyInstaller:
#    pyinstaller --onefile --add-data "/ruta/a/icons:icons" PyYad.py
#
# Ahora puedes usar:
#    python3 $HOME/PyYad/PyYad.py
# o ejecutar el binario:
#    $HOME/PyYad/dist/PyYad
# Incluso reemplazar llamadas a `yad` en tus scripts bash.
