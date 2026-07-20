#!/usr/bin/env python3
import struct
import sys
import time
import select
import os
import re
import fcntl

# Formato del struct input_event en Linux de 64 bits:
# timeval (16 bytes), type (2 bytes), code (2 bytes), value (4 bytes)
EVENT_FORMAT = 'QQHHi'
EVENT_SIZE = struct.calcsize(EVENT_FORMAT)

EV_KEY = 1
KEY_ENTER = 28

# ioctl para tomar control exclusivo del dispositivo de entrada (bloquea que las teclas lleguen a la consola)
EVIOCGRAB = 0x40044590

def find_keyboard_devices():
    devices = []
    current_device = {}
    
    if not os.path.exists('/proc/bus/input/devices'):
        return ['/dev/input/event4']  # fallback
        
    with open('/proc/bus/input/devices', 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                if 'Handlers' in current_device and 'Name' in current_device:
                    handlers = current_device['Handlers']
                    name = current_device['Name'].lower()
                    if 'kbd' in handlers:
                        event_match = re.search(r'event(\d+)', handlers)
                        if event_match:
                            event_node = f"/dev/input/event{event_match.group(1)}"
                            if 'keyboard' in name or 'kbd' in name or 'set 2' in name:
                                devices.append(event_node)
                current_device = {}
                continue
                
            parts = line.split('=', 1)
            if len(parts) == 2:
                key = parts[0].strip()
                val = parts[1].strip().strip('"')
                if key.startswith('N'):
                    current_device['Name'] = val
                elif key.startswith('H'):
                    current_device['Handlers'] = val

    if not devices:
        with open('/proc/bus/input/devices', 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    if 'Handlers' in current_device:
                        handlers = current_device['Handlers']
                        if 'kbd' in handlers:
                            event_match = re.search(r'event(\d+)', handlers)
                            if event_match:
                                devices.append(f"/dev/input/event{event_match.group(1)}")
                    current_device = {}
                    continue
                parts = line.split('=', 1)
                if len(parts) == 2:
                    key = parts[0].strip()
                    val = parts[1].strip().strip('"')
                    if key.startswith('H'):
                        current_device['Handlers'] = val

    return list(set(devices))

def get_ac_status():
    # Retorna 1 si está conectado a la corriente, 0 si no.
    for path in ['/sys/class/power_supply/ADP1/online', '/sys/class/power_supply/AC/online']:
        if os.path.exists(path):
            try:
                with open(path, 'r') as f:
                    return int(f.read().strip())
            except:
                pass
    return 0

def set_screen_blank(blank):
    # blank=True para apagar pantalla, False para encenderla
    val = '1' if blank else '0'
    for path in ['/sys/class/graphics/fb0/blank', '/sys/class/backlight/intel_backlight/bl_power']:
        if os.path.exists(path):
            try:
                with open(path, 'w') as f:
                    f.write(val)
                break
            except Exception as e:
                print(f"Error modificando pantalla en {path}: {e}", file=sys.stderr)

def main():
    kbd_devices = find_keyboard_devices()
    print(f"Dispositivos de teclado detectados: {kbd_devices}")
    
    # Leer estado inicial de la corriente
    initial_ac = get_ac_status()
    print(f"Estado inicial de la corriente: {'Conectado' if initial_ac == 1 else 'Desconectado'}")
    
    # Abrir teclados y aplicar EVIOCGRAB (tomar control exclusivo)
    fds = []
    for dev in kbd_devices:
        try:
            fd = open(dev, 'rb')
            os.set_blocking(fd.fileno(), False)
            # Agarrar el dispositivo para que las pulsaciones no se escriban en pantalla/consola
            fcntl.ioctl(fd.fileno(), EVIOCGRAB, 1)
            fds.append(fd)
        except Exception as e:
            print(f"No se pudo abrir o tomar control de {dev}: {e}", file=sys.stderr)
            
    if not fds:
        print("Error: No se pudo controlar ningún teclado. Abortando.", file=sys.stderr)
        return

    # Apagar la pantalla (Simular suspensión)
    print("Apagando pantalla (Suspensión por software)...")
    sys.stdout.flush()
    set_screen_blank(True)
    
    woken_by = None
    try:
        while True:
            # 1. Comprobar si se ha conectado corriente eléctrica
            current_ac = get_ac_status()
            if current_ac == 1 and initial_ac == 0:
                woken_by = "Corriente eléctrica conectada"
                break
            
            # 2. Comprobar si se presiona la tecla Enter
            r, _, _ = select.select(fds, [], [], 0.2)
            break_loop = False
            for fd in r:
                try:
                    data = fd.read(EVENT_SIZE)
                    while data and len(data) >= EVENT_SIZE:
                        chunk = data[:EVENT_SIZE]
                        data = data[EVENT_SIZE:]
                        sec, usec, etype, code, value = struct.unpack(EVENT_FORMAT, chunk)
                        if etype == EV_KEY and value == 1:  # Presión de tecla (key down)
                            if code == KEY_ENTER:
                                woken_by = "Tecla Enter"
                                break_loop = True
                                break
                            else:
                                # Cualquier otra tecla es ignorada
                                pass
                except BlockingIOError:
                    pass
            if break_loop:
                break
                
            time.sleep(0.05)
    finally:
        # Restaurar pantalla
        set_screen_blank(False)
        # Liberar los dispositivos de teclado
        for fd in fds:
            try:
                fcntl.ioctl(fd.fileno(), EVIOCGRAB, 0)
            except:
                pass
            fd.close()
            
    print(f"\nSistema reactivado por: {woken_by}")

if __name__ == '__main__':
    main()
