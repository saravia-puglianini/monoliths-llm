#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <locale.h>

#define MAX_WINDOWS 1000

Display *dpy;
Window root;
int screen, screen_width, screen_height;

int xi_opcode;
KeyCode tab_code;
KeyCode alt_l_code, alt_r_code, meta_l_code, meta_r_code, super_l_code, super_r_code;
Window ignore_unmap_window = None;

// Window list in MRU order
Window managed_windows[MAX_WINDOWS];
int num_managed = 0;

// Colors & graphics
unsigned long color_bg, color_fg, color_sel_bg, color_sel_fg, color_border, color_cyan, color_magenta;
XFontSet font_set;
int font_ascent = 0;
int font_descent = 0;
GC gc;

unsigned long get_color(const char *name) {
    Colormap cmap = DefaultColormap(dpy, screen);
    XColor color;
    return (XParseColor(dpy, cmap, name, &color) && XAllocColor(dpy, cmap, &color)) ? color.pixel : BlackPixel(dpy, screen);
}

void init_colors() {
    color_bg = get_color("#ecefe4");
    color_fg = get_color("#16161a");
    color_sel_bg = get_color("#7209b7");
    color_sel_fg = get_color("#ffffff");
    color_border = get_color("#3f37c9");
    color_cyan = get_color("#4cc9f0");
    color_magenta = get_color("#f72585");
}

void get_window_title(Window w, char *buf, int max_len) {
    char *name = NULL;
    if (XFetchName(dpy, w, &name) && name && *name) {
        snprintf(buf, max_len, "%s", name);
        XFree(name);
        return;
    }
    if (name) XFree(name);

    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char *prop = NULL;
    if (XGetWindowProperty(dpy, w, XInternAtom(dpy, "_NET_WM_NAME", False), 0, 1024, False,
                           XInternAtom(dpy, "UTF8_STRING", False), &actual_type, &actual_format,
                           &nitems, &bytes_after, &prop) == Success && prop) {
        snprintf(buf, max_len, "%s", prop);
        XFree(prop);
        return;
    }
    snprintf(buf, max_len, "Untitled Window");
}

int is_emacs(Window w) {
    XClassHint chint;
    int res = 0;
    if (XGetClassHint(dpy, w, &chint)) {
        if (chint.res_name && strcasecmp(chint.res_name, "emacs") == 0) {
            res = 1;
        } else if (chint.res_class && strcasecmp(chint.res_class, "emacs") == 0) {
            res = 1;
        }
        if (chint.res_name) XFree(chint.res_name);
        if (chint.res_class) XFree(chint.res_class);
    }
    return res;
}

void update_window_list_file() {
    FILE *f = fopen("/tmp/emacs_non_emacs_windows", "w");
    if (!f) return;
    for (int i = 0; i < num_managed; i++) {
        Window w = managed_windows[i];
        if (!is_emacs(w)) {
            char title[256];
            get_window_title(w, title, sizeof(title));
            fprintf(f, "%lu\t%s\n", (unsigned long)w, title);
        }
    }
    fclose(f);
}

void remove_window(Window w) {
    for (int i = 0; i < num_managed; i++) {
        if (managed_windows[i] == w) {
            memmove(&managed_windows[i], &managed_windows[i + 1], (num_managed - i - 1) * sizeof(Window));
            num_managed--;
            update_window_list_file();
            return;
        }
    }
}

void add_window(Window w) {
    remove_window(w);
    if (num_managed < MAX_WINDOWS) {
        memmove(&managed_windows[1], &managed_windows[0], num_managed * sizeof(Window));
        managed_windows[0] = w;
        num_managed++;
        XSelectInput(dpy, w, PropertyChangeMask);
        update_window_list_file();
    }
}

int is_manageable(Window w) {
    XWindowAttributes attrs;
    if (!XGetWindowAttributes(dpy, w, &attrs) || attrs.override_redirect) {
        return 0;
    }

    // Exclude transient windows (popups, dropdowns, dialogs linked to a parent main window)
    Window transient_for = None;
    if (XGetTransientForHint(dpy, w, &transient_for) && transient_for != None && transient_for != root) {
        return 0;
    }

    // Exclude popup, dropdown, menu, tooltip, utility, and dialog window types
    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char *prop = NULL;
    Atom net_wm_type = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);

    if (XGetWindowProperty(dpy, w, net_wm_type, 0, 32, False,
                           XA_ATOM, &actual_type, &actual_format,
                           &nitems, &bytes_after, &prop) == Success && prop) {
        Atom *types = (Atom *)prop;
        Atom type_dropdown = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DROPDOWN_MENU", False);
        Atom type_popup = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_POPUP_MENU", False);
        Atom type_menu = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_MENU", False);
        Atom type_tooltip = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_TOOLTIP", False);
        Atom type_notification = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_NOTIFICATION", False);
        Atom type_combo = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_COMBO", False);
        Atom type_utility = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_UTILITY", False);
        Atom type_dialog = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False);
        Atom type_dock = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
        Atom type_splash = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_SPLASH", False);

        for (unsigned long i = 0; i < nitems; i++) {
            if (types[i] == type_dropdown || types[i] == type_popup ||
                types[i] == type_menu || types[i] == type_tooltip ||
                types[i] == type_notification || types[i] == type_combo ||
                types[i] == type_utility || types[i] == type_dialog ||
                types[i] == type_dock || types[i] == type_splash) {
                XFree(prop);
                return 0;
            }
        }
        XFree(prop);
    }

    return 1;
}

void maximize_window(Window w) {
    if (is_manageable(w)) {
        XMoveResizeWindow(dpy, w, 0, 0, screen_width, screen_height);
        XSetWindowBorderWidth(dpy, w, 0);
    }
}

void glitch_window(Window w) {
    XWindowAttributes attrs;
    if (!XGetWindowAttributes(dpy, w, &attrs) || attrs.map_state != IsViewable) return;

    XSetWindowAttributes sattrs;
    sattrs.override_redirect = True;
    sattrs.background_pixel = color_bg;
    sattrs.border_pixel = color_border;
    sattrs.event_mask = StructureNotifyMask;

    Window overlay = XCreateWindow(dpy, root, attrs.x, attrs.y, attrs.width, attrs.height, 0,
                                   CopyFromParent, InputOutput, CopyFromParent,
                                   CWOverrideRedirect | CWBackPixel | CWBorderPixel | CWEventMask, &sattrs);

    XMapRaised(dpy, overlay);
    XSync(dpy, False);

    for (int f = 0; f < 5; f++) {
        XSetForeground(dpy, gc, (rand() % 3 == 0) ? color_magenta : ((rand() % 2 == 0) ? color_cyan : color_bg));
        XFillRectangle(dpy, overlay, gc, 0, 0, attrs.width, attrs.height);

        int lines = 5 + (rand() % 10);
        for (int i = 0; i < lines; i++) {
            XSetForeground(dpy, gc, (rand() % 2) ? color_cyan : color_magenta);
            XFillRectangle(dpy, overlay, gc, rand() % attrs.width, rand() % attrs.height,
                           50 + (rand() % 150), 2 + (rand() % 20));
        }
        XFlush(dpy);
        usleep(15000);
    }

    XDestroyWindow(dpy, overlay);
    XFlush(dpy);
}

void set_active_window_prop(Window w) {
    Atom net_active = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
    XChangeProperty(dpy, root, net_active, XA_WINDOW, 32, PropModeReplace,
                    (unsigned char *)&w, 1);
}

void focus_emacs() {
    for (int i = 0; i < num_managed; i++) {
        if (is_emacs(managed_windows[i])) {
            Window target = managed_windows[i];
            XRaiseWindow(dpy, target);
            XSetInputFocus(dpy, target, RevertToPointerRoot, CurrentTime);
            set_active_window_prop(target);
            add_window(target);
            glitch_window(target);
            return;
        }
    }
    // Search in root windows if not yet in managed_windows
    unsigned int nwindows;
    Window root_ret, parent_ret, *windows = NULL;
    if (XQueryTree(dpy, root, &root_ret, &parent_ret, &windows, &nwindows) && windows) {
        for (unsigned int i = 0; i < nwindows; i++) {
            if (is_emacs(windows[i])) {
                Window target = windows[i];
                XRaiseWindow(dpy, target);
                XSetInputFocus(dpy, target, RevertToPointerRoot, CurrentTime);
                set_active_window_prop(target);
                add_window(target);
                glitch_window(target);
                XFree(windows);
                return;
            }
        }
        XFree(windows);
    }
}

int handle_error(Display *d, XErrorEvent *e) {
    (void)d; (void)e;
    return 0;
}

int main() {
    dpy = XOpenDisplay(NULL);
    if (!dpy) return 1;

    XSetErrorHandler(handle_error);

    screen = DefaultScreen(dpy);
    root = RootWindow(dpy, screen);
    screen_width = DisplayWidth(dpy, screen);
    screen_height = DisplayHeight(dpy, screen);

    Atom net_supported = XInternAtom(dpy, "_NET_SUPPORTED", False);
    Atom net_active = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
    Atom net_wm_name = XInternAtom(dpy, "_NET_WM_NAME", False);
    Atom supported[] = { net_active, net_wm_name };
    XChangeProperty(dpy, root, net_supported, XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)supported, 2);

    XSetWindowBackground(dpy, root, WhitePixel(dpy, screen));
    XClearWindow(dpy, root);

    setlocale(LC_ALL, "");

    char **missing_list;
    int missing_count;
    char *def_string;
    font_set = XCreateFontSet(dpy, "-*-liberation sans-medium-r-normal--14-*-*-*-*-*-*-*,fixed,*", &missing_list, &missing_count, &def_string);
    if (!font_set) return 1;

    XFontSetExtents *ext = XExtentsOfFontSet(font_set);
    font_ascent = -ext->max_logical_extent.y;
    font_descent = ext->max_logical_extent.height - font_ascent;

    init_colors();

    gc = XCreateGC(dpy, root, 0, NULL);

    XSelectInput(dpy, root, SubstructureRedirectMask | SubstructureNotifyMask | KeyPressMask | KeyReleaseMask);

    tab_code = XKeysymToKeycode(dpy, XK_Tab);
    alt_l_code = XKeysymToKeycode(dpy, XK_Alt_L);
    alt_r_code = XKeysymToKeycode(dpy, XK_Alt_R);
    meta_l_code = XKeysymToKeycode(dpy, XK_Meta_L);
    meta_r_code = XKeysymToKeycode(dpy, XK_Meta_R);
    super_l_code = XKeysymToKeycode(dpy, XK_Super_L);
    super_r_code = XKeysymToKeycode(dpy, XK_Super_R);

    unsigned int base_mods[] = { Mod1Mask, Mod1Mask | ShiftMask, Mod4Mask, Mod4Mask | ShiftMask };
    unsigned int lock_mods[] = { 0, LockMask, Mod2Mask, LockMask | Mod2Mask, Mod5Mask, LockMask | Mod5Mask, Mod2Mask | Mod5Mask, LockMask | Mod2Mask | Mod5Mask };

    for (size_t b = 0; b < sizeof(base_mods) / sizeof(base_mods[0]); b++) {
        for (size_t l = 0; l < sizeof(lock_mods) / sizeof(lock_mods[0]); l++) {
            XGrabKey(dpy, tab_code, base_mods[b] | lock_mods[l], root, False, GrabModeAsync, GrabModeAsync);
        }
    }

    int xi_event, xi_error;
    if (XQueryExtension(dpy, "XInputExtension", &xi_opcode, &xi_event, &xi_error)) {
        unsigned char mask_bytes[XIMaskLen(XI_LASTEVENT)];
        memset(mask_bytes, 0, sizeof(mask_bytes));
        XISetMask(mask_bytes, XI_RawKeyPress);

        XIEventMask evmask;
        evmask.deviceid = XIAllMasterDevices;
        evmask.mask_len = sizeof(mask_bytes);
        evmask.mask = mask_bytes;

        XISelectEvents(dpy, root, &evmask, 1);
    }

    unsigned int nwindows;
    Window root_ret, parent_ret, *windows = NULL;
    if (XQueryTree(dpy, root, &root_ret, &parent_ret, &windows, &nwindows) && windows) {
        for (unsigned int i = 0; i < nwindows; i++) {
            XWindowAttributes attrs;
            if (XGetWindowAttributes(dpy, windows[i], &attrs) && !attrs.override_redirect && attrs.map_state == IsViewable) {
                add_window(windows[i]);
                maximize_window(windows[i]);
            }
        }
        XFree(windows);
    }

    XEvent ev;
    while (1) {
        XNextEvent(dpy, &ev);

        if (ev.type == GenericEvent && XGetEventData(dpy, &ev.xcookie)) {
            XGenericEventCookie *cookie = &ev.xcookie;
            if (cookie->extension == xi_opcode && cookie->evtype == XI_RawKeyPress) {
                XIRawEvent *raw = (XIRawEvent *)cookie->data;
                if (raw->detail == tab_code) {
                    char keys[32];
                    XQueryKeymap(dpy, keys);
                    int alt_down = (alt_l_code && (keys[alt_l_code >> 3] & (1 << (alt_l_code & 7)))) ||
                                   (alt_r_code && (keys[alt_r_code >> 3] & (1 << (alt_r_code & 7)))) ||
                                   (meta_l_code && (keys[meta_l_code >> 3] & (1 << (meta_l_code & 7)))) ||
                                   (meta_r_code && (keys[meta_r_code >> 3] & (1 << (meta_r_code & 7)))) ||
                                   (super_l_code && (keys[super_l_code >> 3] & (1 << (super_l_code & 7)))) ||
                                   (super_r_code && (keys[super_r_code >> 3] & (1 << (super_r_code & 7))));
                    if (alt_down) {
                        focus_emacs();
                    }
                }
            }
            XFreeEventData(dpy, cookie);
            continue;
        }

        switch (ev.type) {
            case MapRequest: {
                Window w = ev.xmaprequest.window;
                int manageable = is_manageable(w);
                if (manageable) {
                    add_window(w);
                    maximize_window(w);
                }
                XMapWindow(dpy, w);
                XSetInputFocus(dpy, w, RevertToPointerRoot, CurrentTime);
                set_active_window_prop(w);
                if (manageable) glitch_window(w);
                break;
            }
            case ConfigureRequest: {
                XConfigureRequestEvent *cre = &ev.xconfigurerequest;
                XWindowChanges wc;
                if (is_manageable(cre->window)) {
                    wc.x = 0; wc.y = 0;
                    wc.width = screen_width; wc.height = screen_height;
                    wc.border_width = 0;
                    wc.sibling = cre->above; wc.stack_mode = cre->detail;
                    XConfigureWindow(dpy, cre->window, cre->value_mask | CWX | CWY | CWWidth | CWHeight | CWBorderWidth, &wc);
                } else {
                    wc.x = cre->x; wc.y = cre->y;
                    wc.width = cre->width; wc.height = cre->height;
                    wc.border_width = cre->border_width;
                    wc.sibling = cre->above; wc.stack_mode = cre->detail;
                    XConfigureWindow(dpy, cre->window, cre->value_mask, &wc);
                }
                break;
            }
            case UnmapNotify:
                if (ev.xunmap.window == ignore_unmap_window) {
                    ignore_unmap_window = None;
                    break;
                }
                remove_window(ev.xunmap.window);
                if (num_managed == 0) XClearWindow(dpy, root);
                break;
            case DestroyNotify:
                remove_window(ev.xdestroywindow.window);
                if (num_managed == 0) XClearWindow(dpy, root);
                break;
            case PropertyNotify: {
                if (ev.xproperty.atom == XInternAtom(dpy, "_NET_WM_NAME", False) ||
                    ev.xproperty.atom == XA_WM_NAME) {
                    update_window_list_file();
                }
                break;
            }
            case ClientMessage: {
                Atom net_active = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
                if (ev.xclient.message_type == net_active) {
                    Window w = ev.xclient.window;
                    if (w != None && is_manageable(w)) {
                        XRaiseWindow(dpy, w);
                        XSetInputFocus(dpy, w, RevertToPointerRoot, CurrentTime);
                        set_active_window_prop(w);
                        add_window(w);
                        glitch_window(w);
                    }
                }
                break;
            }
            case KeyPress: {
                if (ev.xkey.keycode == tab_code) {
                    focus_emacs();
                }
                break;
            }
        }
    }
    XCloseDisplay(dpy);
    return 0;
}

/*
==============================================================================
  ELISP CODE FOR YOUR ~/.emacs.d/init.el (O cargar alt_tab_external_buffers.el)
==============================================================================
  Copiar el siguiente codigo en tu ~/.emacs.d/init.el:

(defcustom my-external-buffer-format "*Ext: %s*"
  "Formato para los nombres de buffers de ventanas externas. %s se reemplaza por el título de la ventana."
  :type 'string
  :group 'external-windows)

(defvar-local my-external-window-id nil
  "ID de la ventana X11 asociada a este buffer.")

(defvar my-last-real-buffer nil
  "Último buffer normal (no externo) visitado por el usuario.")

(defvar my-external-windows-hash (make-hash-table :test 'equal)
  "Mapeo de ID de ventana X11 a objeto buffer.")

(defun my-update-last-real-buffer ()
  "Registra el último buffer activo que no sea una ventana externa ni el minibuffer."
  (unless (or (bound-and-true-p my-external-window-id)
              (minibufferp)
              (string-prefix-p " " (buffer-name)))
    (setq my-last-real-buffer (current-buffer))))

(defun my-activate-external-window-id (win-id)
  "Ejecuta xdotool para activar la ventana con ID WIN-ID."
  (call-process "xdotool" nil 0 nil "windowactivate" (format "%s" win-id)))

(defun my-check-and-trigger-external-windows (&optional frame)
  "Verifica si alguna ventana de Emacs muestra un buffer externo y dispara la ventana real."
  (dolist (win (window-list frame))
    (let ((buf (window-buffer win)))
      (when (and (buffer-live-p buf)
                 (buffer-local-value 'my-external-window-id buf))
        (let ((win-id (buffer-local-value 'my-external-window-id buf))
              (title (buffer-name buf))
              (fallback (if (and my-last-real-buffer (buffer-live-p my-last-real-buffer))
                            my-last-real-buffer
                          (other-buffer buf t))))
          ;; Restaurar el buffer anterior en la ventana de Emacs
          (set-window-buffer win fallback)
          ;; Activar la ventana real externa en X11
          (my-activate-external-window-id win-id)
          (message "Ventana externa activada: %s" title))))))

(defun my-sync-external-window-buffers ()
  "Sincroniza los buffers individuales de Emacs con la lista /tmp/emacs_non_emacs_windows."
  (interactive)
  (let ((file "/tmp/emacs_non_emacs_windows")
        (current-ids (make-hash-table :test 'equal)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                 (parts (split-string line "\t")))
            (when (>= (length parts) 2)
              (let* ((win-id (nth 0 parts))
                     (win-title (nth 1 parts))
                     (buf-name (format my-external-buffer-format win-title))
                     (existing-buf (gethash win-id my-external-windows-hash))
                     (buf (get-buffer buf-name)))
                (puthash win-id t current-ids)
                ;; Si la ventana cambió de título, eliminar el buffer con el título viejo
                (when (and existing-buf
                           (buffer-live-p existing-buf)
                           (not (string= (buffer-name existing-buf) buf-name)))
                  (kill-buffer existing-buf))
                (if (and buf (buffer-live-p buf))
                    (with-current-buffer buf
                      (setq-local my-external-window-id win-id))
                  (setq buf (get-buffer-create buf-name))
                  (with-current-buffer buf
                    (setq-local my-external-window-id win-id)
                    (let ((inhibit-read-only t))
                      (erase-buffer)
                      (insert (format "=== VENTANA EXTERNA X11 ===\nID: %s\nTítulo: %s\n\nEste buffer representa una ventana del sistema.\nAl ser visualizado, Emacs enfoca la ventana real y regresa al buffer anterior."
                                      win-id win-title))
                      (read-only-mode 1))))
                (puthash win-id buf my-external-windows-hash))))
          (forward-line 1))))
    ;; Eliminar buffers de ventanas cerradas
    (maphash (lambda (win-id buf)
               (unless (gethash win-id current-ids)
                 (when (buffer-live-p buf)
                   (kill-buffer buf))
                 (remhash win-id my-external-windows-hash)))
             my-external-windows-hash)))

(defun my-activate-window-at-point ()
  "Activa la ventana seleccionada en la línea actual."
  (interactive)
  (let ((id (get-text-property (point) 'window-id)))
    (unless id
      (save-excursion
        (beginning-of-line)
        (when (re-search-forward "\\[ \\([0-9]+\\) \\]" (line-end-position) t)
          (setq id (match-string 1)))))
    (if id
        (progn
          (my-activate-external-window-id id)
          (message "Ventana %s activada" id))
      (message "No hay ID de ventana en esta línea"))))

(define-derived-mode external-windows-mode special-mode "External-Windows"
  "Modo interactivo para el buffer de ventanas externas."
  (define-key external-windows-mode-map (kbd "RET") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "<return>") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "<mouse-2>") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "<down-mouse-1>") #'my-activate-window-at-point)
  (define-key external-windows-mode-map (kbd "g") #'my-update-external-windows))

(defun my-update-external-windows ()
  "Actualiza el buffer *External Windows* y los buffers individuales."
  (interactive)
  (my-sync-external-window-buffers)
  (let ((buf (get-buffer-create "*External Windows*"))
        (file "/tmp/emacs_non_emacs_windows"))
    (when (file-exists-p file)
      (with-current-buffer buf
        (unless (eq major-mode 'external-windows-mode)
          (external-windows-mode))
        (let ((inhibit-read-only t)
              (old-pos (point)))
          (erase-buffer)
          (insert "=== VENTANAS ABIERTAS (FUERA DE EMACS) ===\n")
          (insert "Presiona ENTER en cualquier línea para cambiar a esa ventana.\n")
          (insert "También puedes usar C-x b <NombreVentana> para ir directamente.\n\n")
          (with-temp-buffer
            (insert-file-contents file)
            (goto-char (point-min))
            (while (not (eobp))
              (let* ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                     (parts (split-string line "\t")))
                (when (>= (length parts) 2)
                  (let* ((win-id (nth 0 parts))
                         (win-title (nth 1 parts))
                         (line-text (format "[ %s ] %s" win-id win-title))
                         (start (point)))
                    (with-current-buffer buf
                      (insert-button line-text
                                     'action (lambda (btn)
                                               (let ((id (button-get btn 'window-id)))
                                                 (when id
                                                   (my-activate-external-window-id id))))
                                     'window-id win-id
                                     'follow-link t)
                      (add-text-properties start (point) `(window-id ,win-id))
                      (insert "\n")))))
              (forward-line 1)))
          (goto-char (max (point-min) (min old-pos (point-max)))))))))

(defvar my-external-windows-timer nil)
(defvar my-external-windows-thread nil)

(defun my-start-external-windows-tracker ()
  "Inicia la sincronización periódica de ventanas externas y hooks en Emacs."
  (interactive)
  (add-hook 'post-command-hook #'my-update-last-real-buffer)
  (add-hook 'post-command-hook #'my-check-and-trigger-external-windows)
  (add-hook 'window-state-change-hook #'my-check-and-trigger-external-windows)

  (unless (or my-external-windows-timer
              (and my-external-windows-thread (thread-alive-p my-external-windows-thread)))
    (if (fboundp 'make-thread)
        (setq my-external-windows-thread
              (make-thread
               (lambda ()
                 (while t
                   (ignore-errors (my-update-external-windows))
                   (sleep-for 1)))
               "external-windows-tracker"))
      (setq my-external-windows-timer
            (run-with-timer 0 1 #'my-update-external-windows)))
    (message "Rastreador de ventanas externas y buffers automáticos iniciado.")))

(defun my-stop-external-windows-tracker ()
  "Detiene el rastreador de ventanas externas."
  (interactive)
  (remove-hook 'post-command-hook #'my-update-last-real-buffer)
  (remove-hook 'post-command-hook #'my-check-and-trigger-external-windows)
  (remove-hook 'window-state-change-hook #'my-check-and-trigger-external-windows)
  (when my-external-windows-timer
    (cancel-timer my-external-windows-timer)
    (setq my-external-windows-timer nil))
  (when (and my-external-windows-thread (thread-alive-p my-external-windows-thread))
    (thread-signal my-external-windows-thread 'quit nil)
    (setq my-external-windows-thread nil))
  (message "Rastreador de ventanas externas detenido."))

;; Iniciar automáticamente el rastreador al abrir Emacs:
(my-start-external-windows-tracker)

==============================================================================
*/

/*
  Do a folder
  ~/alt_tab_maximize_emacs-buffer_only/Makefile
  ~/alt_tab_maximize_emacs-buffer_only/alt_tab_maximize_emacs-buffer_only.c
  ~/alt_tab_maximize_emacs-buffer_only/alt_tab_maximize_emacs-buffer_only-session
*/

/*

# DO A Makefile

       CC = gcc
       CFLAGS = -Wall -Wextra -Ofast -flto -s -fno-asynchronous-unwind-tables -fno-ident
       LIBS = -lX11 -lXi
       PREFIX ?= /usr/local

       all: alt_tab_maximize_emacs-buffer_only

       alt_tab_maximize_emacs-buffer_only: alt_tab_maximize_emacs-buffer_only.c
	       $(CC) $(CFLAGS) -o alt_tab_maximize_emacs-buffer_only alt_tab_maximize_emacs-buffer_only.c $(LIBS)
	       chmod +x alt_tab_maximize_emacs-buffer_only alt_tab_maximize_emacs-buffer_only-session

       install: all
	       mkdir -p $(DESTDIR)$(PREFIX)/bin
	       cp -f alt_tab_maximize_emacs-buffer_only $(DESTDIR)$(PREFIX)/bin
	       cp -f alt_tab_maximize_emacs-buffer_only-session $(DESTDIR)$(PREFIX)/bin
		      chmod 755 $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_emacs-buffer_only
	      chmod 755 $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_emacs-buffer_only-session

      uninstall:
	      rm -f $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_emacs-buffer_only
	      rm -f $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_emacs-buffer_only-session

      clean:
	      rm -f alt_tab_maximize_emacs-buffer_only

*/

/*
# DO A file ~/alt_tab_maximize_emacs-buffer_only/alt_tab_maximize_emacs-buffer_only-session with:

      #!/bin/sh
      # Session wrapper for alt_tab_maximize_emacs-buffer_only window manager

      # If alt_tab_maximize_emacs-buffer_only is in the same directory, run it, otherwise assume it's in the PATH
      if [ -x "$(dirname "$0")/alt_tab_maximize_emacs-buffer_only" ]; then
	  exec "$(dirname "$0")/alt_tab_maximize_emacs-buffer_only"
      else
	  exec alt_tab_maximize_emacs-buffer_only
      fi

*/