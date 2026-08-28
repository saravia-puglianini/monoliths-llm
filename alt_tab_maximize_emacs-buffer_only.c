#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <locale.h>
#include <stdarg.h>

#define MAX_WINDOWS 1000

Display *dpy;
Window root;
int screen, screen_width, screen_height;

KeyCode tab_code;
KeyCode alt_l_code, alt_r_code, meta_l_code, meta_r_code, super_l_code, super_r_code;
Window ignore_unmap_window = None;

// Cache X11 atoms once to avoid repeated server round trips in hot paths.
Atom atom_net_active, atom_net_wm_name, atom_net_wm_type, atom_utf8_string;
Atom atom_type_dropdown, atom_type_popup, atom_type_menu, atom_type_tooltip;
Atom atom_type_notification, atom_type_combo, atom_type_utility, atom_type_dialog;
Atom atom_type_dock, atom_type_splash, atom_type_normal, atom_motif_wm_hints;

// Window list in MRU order
Window managed_windows[MAX_WINDOWS];
int num_managed = 0;

// Colors & graphics
unsigned long color_bg, color_fg, color_sel_bg, color_sel_fg, color_border;
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
    if (XGetWindowProperty(dpy, w, atom_net_wm_name, 0, 1024, False,
                           atom_utf8_string, &actual_type, &actual_format,
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

int is_managed_window(Window w) {
    for (int i = 0; i < num_managed; i++) {
        if (managed_windows[i] == w) return 1;
    }
    return 0;
}

void add_window(Window w) {
    // Reorder an existing entry without exporting the list twice.
    for (int i = 0; i < num_managed; i++) {
        if (managed_windows[i] == w) {
            memmove(&managed_windows[i], &managed_windows[i + 1],
                    (num_managed - i - 1) * sizeof(Window));
            num_managed--;
            break;
        }
    }
    if (num_managed < MAX_WINDOWS) {
        memmove(&managed_windows[1], &managed_windows[0], num_managed * sizeof(Window));
        managed_windows[0] = w;
        num_managed++;
        XSelectInput(dpy, w, PropertyChangeMask);
        update_window_list_file();
    }
}

FILE *log_file = NULL;
int logging_enabled = 0;

void log_wm(const char *format, ...) {
    if (!logging_enabled) return;
    if (!log_file) {
        log_file = fopen("/tmp/alt_tab_wm.log", "a");
    }
    if (log_file) {
        va_list args;
        va_start(args, format);
        vfprintf(log_file, format, args);
        va_end(args);
        fprintf(log_file, "\n");
        if (getenv("ALT_TAB_SYNC_LOG")) fflush(log_file);
    }
}

int is_manageable(Window w) {
    XWindowAttributes attrs;
    if (!XGetWindowAttributes(dpy, w, &attrs)) {
        log_wm("[is_manageable] Window 0x%lx: Failed to get attributes -> NO", (unsigned long)w);
        return 0;
    }
    if (attrs.override_redirect) {
        log_wm("[is_manageable] Window 0x%lx: override_redirect=True -> NO", (unsigned long)w);
        return 0;
    }

    // Exclude transient windows (popups, dropdowns, dialogs linked to a parent main window)
    Window transient_for = None;
    if (XGetTransientForHint(dpy, w, &transient_for) && transient_for != None && transient_for != root) {
        log_wm("[is_manageable] Window 0x%lx: transient_for=0x%lx -> NO", (unsigned long)w, (unsigned long)transient_for);
        return 0;
    }

    // Check size hints (fixed-size dialogs/popups or windows requesting specific positions)
    XSizeHints size_hints;
    long supplied_hints;
    if (XGetWMNormalHints(dpy, w, &size_hints, &supplied_hints)) {
        if ((size_hints.flags & PMinSize) && (size_hints.flags & PMaxSize)) {
            if (size_hints.min_width > 0 && size_hints.min_height > 0 &&
                size_hints.min_width == size_hints.max_width &&
                size_hints.min_height == size_hints.max_height) {
                log_wm("[is_manageable] Window 0x%lx: fixed size (%dx%d) -> NO",
                       (unsigned long)w, size_hints.min_width, size_hints.min_height);
                return 0;
            }
        }
        if ((size_hints.flags & PMaxSize) &&
            (size_hints.max_width < screen_width / 2 || size_hints.max_height < screen_height / 2)) {
            log_wm("[is_manageable] Window 0x%lx: max_size too small (%dx%d) -> NO",
                   (unsigned long)w, size_hints.max_width, size_hints.max_height);
            return 0;
        }
    }

    // Exclude popup, dropdown, menu, tooltip, utility, and dialog window types
    Atom actual_type;
    int actual_format;
    unsigned long nitems, bytes_after;
    unsigned char *prop = NULL;
    if (XGetWindowProperty(dpy, w, atom_net_wm_type, 0, 32, False,
                           XA_ATOM, &actual_type, &actual_format,
                           &nitems, &bytes_after, &prop) == Success && prop) {
        Atom *types = (Atom *)prop;
        int has_non_normal = 0;
        for (unsigned long i = 0; i < nitems; i++) {
            if (types[i] == atom_type_dropdown || types[i] == atom_type_popup ||
                types[i] == atom_type_menu || types[i] == atom_type_tooltip ||
                types[i] == atom_type_notification || types[i] == atom_type_combo ||
                types[i] == atom_type_utility || types[i] == atom_type_dialog ||
                types[i] == atom_type_dock || types[i] == atom_type_splash) {
                has_non_normal = 1;
                break;
            }
        }
        if (has_non_normal) {
            log_wm("[is_manageable] Window 0x%lx: Matched non-normal _NET_WM_WINDOW_TYPE -> NO", (unsigned long)w);
            XFree(prop);
            return 0;
        }

        int has_normal = 0;
        for (unsigned long i = 0; i < nitems; i++) {
            if (types[i] == atom_type_normal) {
                has_normal = 1;
                break;
            }
        }
        XFree(prop);
        if (has_normal) {
            log_wm("[is_manageable] Window 0x%lx: Explicit _NET_WM_WINDOW_TYPE_NORMAL -> YES", (unsigned long)w);
            return 1;
        }
    }

    // Check Motif Hints (dialogs/popups without decorations)
    if (XGetWindowProperty(dpy, w, atom_motif_wm_hints, 0, 20, False,
                           atom_motif_wm_hints, &actual_type, &actual_format,
                           &nitems, &bytes_after, &prop) == Success && prop) {
        if (nitems >= 5) {
            unsigned long *hints = (unsigned long *)prop;
            unsigned long flags = hints[0];
            unsigned long decorations = hints[2];
            // MWM_HINTS_DECORATIONS = 2. If decorations specified and 0, and not normal window
            if ((flags & 2) && decorations == 0) {
                char title[256];
                get_window_title(w, title, sizeof(title));
                // If it doesn't have a title or is small, likely a dropdown/popup
                if (attrs.width < screen_width * 0.8 && attrs.height < screen_height * 0.8) {
                    log_wm("[is_manageable] Window 0x%lx ('%s'): MWM undecorated + dimensions (%dx%d) -> NO",
                           (unsigned long)w, title, attrs.width, attrs.height);
                    XFree(prop);
                    return 0;
                }
            }
        }
        XFree(prop);
    }

    char title[256];
    get_window_title(w, title, sizeof(title));
    log_wm("[is_manageable] Window 0x%lx ('%s'): default -> YES", (unsigned long)w, title);
    return 1;
}

void maximize_window(Window w) {
    if (is_manageable(w)) {
        log_wm("[maximize_window] Maximizing Window 0x%lx to (%d x %d)", (unsigned long)w, screen_width, screen_height);
        XMoveResizeWindow(dpy, w, 0, 0, screen_width, screen_height);
        XSetWindowBorderWidth(dpy, w, 0);
    }
}

void set_active_window_prop(Window w) {
    XChangeProperty(dpy, root, atom_net_active, XA_WINDOW, 32, PropModeReplace,
                    (unsigned char *)&w, 1);
}

Window managed_ancestor(Window w) {
    while (w != None && w != root) {
        for (int i = 0; i < num_managed; i++) {
            if (managed_windows[i] == w) return w;
        }

        Window root_ret, parent_ret, *children = NULL;
        unsigned int nchildren = 0;
        if (!XQueryTree(dpy, w, &root_ret, &parent_ret, &children, &nchildren)) {
            break;
        }
        if (children) XFree(children);
        if (parent_ret == w) break;
        w = parent_ret;
    }
    return None;
}

void focus_next_window() {
    if (num_managed < 1) return;

    Window current = None;
    int revert_to;
    XGetInputFocus(dpy, &current, &revert_to);
    current = managed_ancestor(current);

    int current_index = -1;
    for (int i = 0; i < num_managed; i++) {
        if (managed_windows[i] == current) {
            current_index = i;
            break;
        }
    }

    int target_index = current_index >= 0 ? (current_index + 1) % num_managed : 0;
    Window target = managed_windows[target_index];
    if (target == current) return;

    XRaiseWindow(dpy, target);
    XSetInputFocus(dpy, target, RevertToPointerRoot, CurrentTime);
    set_active_window_prop(target);
    add_window(target);
}

void focus_emacs() {
    const char *persistent = getenv("emacs_persistent");

    // Emacs conserva el comportamiento especial solamente cuando la sesión
    // lo declaró persistente. En los demás modos, Alt-Tab es un cambio normal.
    if (!persistent || strcasecmp(persistent, "true") != 0) {
        focus_next_window();
        return;
    }

    for (int i = 0; i < num_managed; i++) {
        if (is_emacs(managed_windows[i])) {
            Window target = managed_windows[i];
            XRaiseWindow(dpy, target);
            XSetInputFocus(dpy, target, RevertToPointerRoot, CurrentTime);
            set_active_window_prop(target);
            add_window(target);
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
                XFree(windows);
                return;
            }
        }
        XFree(windows);
    }

    // Sin Emacs, Alt-Tab actúa como un cambio directo y silencioso.
    focus_next_window();
}

int handle_error(Display *d, XErrorEvent *e) {
    (void)d; (void)e;
    return 0;
}

int main() {
    dpy = XOpenDisplay(NULL);
    if (!dpy) return 1;

    XSetErrorHandler(handle_error);

    // Logging is opt-in so the normal event path performs no disk I/O.
    logging_enabled = getenv("ALT_TAB_LOG") != NULL;

    log_wm("=================================================");
    log_wm("[WM STARTED] Initializing window manager");

    screen = DefaultScreen(dpy);
    root = RootWindow(dpy, screen);
    screen_width = DisplayWidth(dpy, screen);
    screen_height = DisplayHeight(dpy, screen);

    Atom net_supported = XInternAtom(dpy, "_NET_SUPPORTED", False);
    atom_net_active = XInternAtom(dpy, "_NET_ACTIVE_WINDOW", False);
    atom_net_wm_name = XInternAtom(dpy, "_NET_WM_NAME", False);
    atom_net_wm_type = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
    atom_utf8_string = XInternAtom(dpy, "UTF8_STRING", False);
    atom_type_normal = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_NORMAL", False);
    atom_type_dropdown = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DROPDOWN_MENU", False);
    atom_type_popup = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_POPUP_MENU", False);
    atom_type_menu = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_MENU", False);
    atom_type_tooltip = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_TOOLTIP", False);
    atom_type_notification = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_NOTIFICATION", False);
    atom_type_combo = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_COMBO", False);
    atom_type_utility = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_UTILITY", False);
    atom_type_dialog = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DIALOG", False);
    atom_type_dock = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_DOCK", False);
    atom_type_splash = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_SPLASH", False);
    atom_motif_wm_hints = XInternAtom(dpy, "_MOTIF_WM_HINTS", False);

    Atom supported[] = {
        atom_net_active, atom_net_wm_name, atom_net_wm_type, atom_type_normal,
        atom_type_dropdown, atom_type_popup, atom_type_menu,
        atom_type_tooltip, atom_type_dialog, atom_type_utility
    };
    XChangeProperty(dpy, root, net_supported, XA_ATOM, 32, PropModeReplace,
                    (unsigned char *)supported, sizeof(supported) / sizeof(Atom));

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

    unsigned int nwindows;
    Window root_ret, parent_ret, *windows = NULL;
    if (XQueryTree(dpy, root, &root_ret, &parent_ret, &windows, &nwindows) && windows) {
        for (unsigned int i = 0; i < nwindows; i++) {
            XWindowAttributes attrs;
            if (XGetWindowAttributes(dpy, windows[i], &attrs) && !attrs.override_redirect && attrs.map_state == IsViewable) {
                if (is_manageable(windows[i])) {
                    add_window(windows[i]);
                    maximize_window(windows[i]);
                }
            }
        }
        XFree(windows);
    }

    XEvent ev;
    while (1) {
        XNextEvent(dpy, &ev);

        switch (ev.type) {
            case MapRequest: {
                Window w = ev.xmaprequest.window;
                if (logging_enabled) {
                    char title[256];
                    get_window_title(w, title, sizeof(title));
                    log_wm("[EVENT: MapRequest] Window 0x%lx ('%s')", (unsigned long)w, title);
                }
                int manageable = is_manageable(w);
                if (manageable) {
                    add_window(w);
                    maximize_window(w);
                    XMapWindow(dpy, w);
                    XSetInputFocus(dpy, w, RevertToPointerRoot, CurrentTime);
                    set_active_window_prop(w);
                } else {
                    // Non-manageable window (e.g. dropdown, popup, tooltip, dialog):
                    // Map and raise it above parent without forcing fullscreen or taking main focus away aggressively
                    XMapRaised(dpy, w);
                }
                break;
            }
            case ConfigureRequest: {
                XConfigureRequestEvent *cre = &ev.xconfigurerequest;
                XWindowChanges wc;
                // A ConfigureRequest may arrive before Chrome has published the
                // popup's type, title or size hints. Reclassifying it here made
                // transient context-menu surfaces look like normal windows and
                // forced them fullscreen. Only windows accepted during
                // MapRequest/startup are allowed to receive fullscreen policy.
                if (is_managed_window(cre->window)) {
                    log_wm("[EVENT: ConfigureRequest] Manageable window 0x%lx -> forcing fullscreen", (unsigned long)cre->window);
                    wc.x = 0; wc.y = 0;
                    wc.width = screen_width; wc.height = screen_height;
                    wc.border_width = 0;
                    wc.sibling = cre->above; wc.stack_mode = cre->detail;
                    XConfigureWindow(dpy, cre->window, cre->value_mask | CWX | CWY | CWWidth | CWHeight | CWBorderWidth, &wc);
                } else {
                    log_wm("[EVENT: ConfigureRequest] Non-manageable window 0x%lx -> allowing requested geom (%d,%d %dx%d)",
                           (unsigned long)cre->window, cre->x, cre->y, cre->width, cre->height);
                    wc.x = cre->x; wc.y = cre->y;
                    wc.width = cre->width; wc.height = cre->height;
                    wc.border_width = cre->border_width;
                    wc.sibling = cre->above; wc.stack_mode = cre->detail;
                    XConfigureWindow(dpy, cre->window, cre->value_mask, &wc);
                }
                break;
            }
            case UnmapNotify:
                log_wm("[EVENT: UnmapNotify] Window 0x%lx", (unsigned long)ev.xunmap.window);
                if (ev.xunmap.window == ignore_unmap_window) {
                    ignore_unmap_window = None;
                    break;
                }
                remove_window(ev.xunmap.window);
                if (num_managed == 0) XClearWindow(dpy, root);
                break;
            case DestroyNotify:
                log_wm("[EVENT: DestroyNotify] Window 0x%lx", (unsigned long)ev.xdestroywindow.window);
                remove_window(ev.xdestroywindow.window);
                if (num_managed == 0) XClearWindow(dpy, root);
                break;
            case PropertyNotify: {
                if (ev.xproperty.atom == atom_net_wm_name ||
                    ev.xproperty.atom == XA_WM_NAME) {
                    update_window_list_file();
                }
                break;
            }
            case ClientMessage: {
                if (ev.xclient.message_type == atom_net_active) {
                    Window w = ev.xclient.window;
                    log_wm("[EVENT: ClientMessage _NET_ACTIVE_WINDOW] Window 0x%lx", (unsigned long)w);
                    if (w != None && is_manageable(w)) {
                        XRaiseWindow(dpy, w);
                        XSetInputFocus(dpy, w, RevertToPointerRoot, CurrentTime);
                        set_active_window_prop(w);
                        add_window(w);
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
    if (log_file) fclose(log_file);
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

;; ==============================================================================
;; HYPERBOLE SCRATCH MENU (Lectura de opciones y menú interactivo)
;; ==============================================================================
(defvar my-shell-script-file (expand-file-name "~/monoliths-hm/my.shell.sh")
  "Ruta al script Shell original de monoliths-hm.")

(defun my-shell-get-items ()
  "Obtiene la lista de ítems ejecutando 'dash ~/monoliths-hm/my.shell.sh'."
  (when (file-exists-p my-shell-script-file)
    (let ((raw-output (with-temp-buffer
                        (call-process "dash" nil t nil my-shell-script-file)
                        (buffer-string)))
          (items nil))
      (dolist (line (split-string raw-output "\n" t))
        ;; Regex mejorada para capturar nombres completos con guiones (ej. ubuntu-01-emacs-29)
        (when (string-match "^\\s-*\\([0-9]+\\))\\s-*\\(.*?\\)\\(?:\\s-+-\\s-+\\(.*\\)\\)?$" line)
          (let* ((id (match-string 1 line))
                 (name (string-trim (match-string 2 line)))
                 (desc (if (match-string 3 line)
                           (string-trim (match-string 3 line))
                         name)))
            (push (list id name desc) items))))
      (nreverse items))))

(defun my-shell-execute-by-id (id &optional name)
  "Ejecuta la opción correspondiente al ID en su propio buffer *<name> shell*."
  (when (file-exists-p my-shell-script-file)
    (let* ((actual-name (or name
                            (nth 1 (assoc id (my-shell-get-items)))))
           (buf-name (format "*%s shell*" (or actual-name id)))
           (display (or (getenv "DISPLAY") ":0"))
           (cmd (format "DISPLAY=%s dash %s -q %s" display my-shell-script-file id)))
      (async-shell-command cmd buf-name))))

(defun generate-hyperbole-scratch-menu ()
  "Genera la tabla interactiva de Hyperbole en *scratch* leyendo my.shell.sh."
  (interactive)
  (let ((scratch-buf (get-buffer-create "*scratch*"))
        (items (my-shell-get-items)))
    (when items
      (with-current-buffer scratch-buf
        (erase-buffer)
        (insert ";; ======================================================================\n")
        (insert ";;                 PANEL DE CONTROL INTERACTIVO (HYPERBOLE)             ;;\n")
        (insert ";; Presione M-RET / Action Key en un botón para ejecutar la acción.    ;;\n")
        (insert ";; ======================================================================\n\n")
        (let ((max-name (length "Acción"))
              (max-desc (length "Descripción"))
              (max-btn (length "Acción Hyperbole (Implicit Button)")))
          (dolist (item items)
            (let* ((id (nth 0 item))
                   (name (nth 1 item))
                   (desc (nth 2 item))
                   (btn (format "{ (my-shell-execute-by-id \"%s\" \"%s\") }" id name)))
              (setq max-name (max max-name (length name)))
              (setq max-desc (max max-desc (length desc)))
              (setq max-btn (max max-btn (length btn)))))
          (let ((sep (format "|-%s-+-%s-+-%s-|"
                             (make-string max-name ?-)
                             (make-string max-desc ?-)
                             (make-string max-btn ?-)))
                (fmt (format "| %%-%ds | %%-%ds | %%-%ds |\n" max-name max-desc max-btn)))
            (insert (format fmt "Acción" "Descripción" "Acción Hyperbole (Implicit Button)"))
            (insert sep "\n")
            (dolist (item items)
              (let* ((id (nth 0 item))
                     (name (nth 1 item))
                     (desc (nth 2 item))
                     (btn (format "{ (my-shell-execute-by-id \"%s\" \"%s\") }" id name)))
                (insert (format fmt name desc btn))))
            (insert sep "\n"))))
      (goto-char (point-min)))))

(with-eval-after-load 'hyperbole
  (defib my-shell-menu-action ()
    "Activates a menu action when clicking on its name or anywhere on the row in the *scratch* buffer."
    (when (string= (buffer-name) "*scratch*")
      (save-excursion
        (beginning-of-line)
        (when (looking-at "|\\s-*\\([^|]+\\S-\\)\\s-*|\\s-*[^|]+\\s-*|\\s-*{\\s-*(my-shell-execute-by-id\\s-+\"\\([0-9]+\\)\"")
          (let ((name (match-string 1))
                (id (match-string 2)))
            (ibut:label-set name (match-beginning 1) (match-end 1))
            (hact 'my-shell-execute-by-id id name)))))))

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
