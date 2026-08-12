#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/XInput2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <locale.h>

#define MAX_WINDOWS 1000

Display *dpy;
Window root;
int screen, screen_width, screen_height;

int xi_opcode;
KeyCode tab_code;
KeyCode alt_l_code, alt_r_code, meta_l_code, meta_r_code;
Window ignore_unmap_window = None;

// Window list in MRU order
Window managed_windows[MAX_WINDOWS];
int num_managed = 0;

// Switcher state
int switcher_active = 0;
Window switcher_popup = None;
int switcher_index = 0;
Window switcher_list[MAX_WINDOWS];
int num_switcher = 0;

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

void remove_window(Window w) {
    for (int i = 0; i < num_managed; i++) {
        if (managed_windows[i] == w) {
            memmove(&managed_windows[i], &managed_windows[i + 1], (num_managed - i - 1) * sizeof(Window));
            num_managed--;
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
    }
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

// Window tile layout structure for mosaic
typedef struct {
    Window win;
    int x, y, width, height;
} Tile;

Tile switcher_tiles[MAX_WINDOWS];
int hovered_tile = -1;

void draw_grid_frame(int is_transition) {
    XSetForeground(dpy, gc, is_transition ? ((rand() % 3 == 0) ? color_magenta : color_bg) : color_bg);
    XFillRectangle(dpy, switcher_popup, gc, 0, 0, screen_width, screen_height);

    if (is_transition || (rand() % 4 == 0)) {
        int lines = is_transition ? (8 + (rand() % 12)) : 3;
        for (int i = 0; i < lines; i++) {
            XSetForeground(dpy, gc, (rand() % 2) ? color_cyan : color_magenta);
            XFillRectangle(dpy, switcher_popup, gc, rand() % screen_width, rand() % screen_height,
                           80 + (rand() % 300), 2 + (rand() % 10));
        }
    }

    for (int i = 0; i < num_switcher; i++) {
        Tile *t = &switcher_tiles[i];
        char title[256];
        get_window_title(t->win, title, sizeof(title));

        int is_hovered = (i == hovered_tile);
        
        // Draw card background
        XSetForeground(dpy, gc, is_hovered ? color_sel_bg : color_bg);
        XFillRectangle(dpy, switcher_popup, gc, t->x, t->y, t->width, t->height);

        // Draw card border
        XSetForeground(dpy, gc, is_hovered ? color_magenta : color_border);
        XSetLineAttributes(dpy, gc, is_hovered ? 3 : 1, LineSolid, CapButt, JoinMiter);
        XDrawRectangle(dpy, switcher_popup, gc, t->x, t->y, t->width, t->height);
        XSetLineAttributes(dpy, gc, 0, LineSolid, CapButt, JoinMiter);

        // Text positioning & glitch effects
        int text_x = t->x + 15;
        int text_y = t->y + (t->height / 2) + (font_ascent / 2);

        int glitch_this = is_transition || (rand() % 10 == 0);
        int offset_x = glitch_this ? (rand() % 9 - 4) : 0;
        
        if (glitch_this && strlen(title) > 2) {
            int glitch_chars = 1 + (rand() % 2);
            for (int g = 0; g < glitch_chars; g++) {
                title[rand() % strlen(title)] = "X#_$%&!01"[rand() % 9];
            }
        }

        if (glitch_this) {
            XSetForeground(dpy, gc, color_cyan);
            Xutf8DrawString(dpy, switcher_popup, font_set, gc, text_x + offset_x - 3, text_y, title, strlen(title));
            XSetForeground(dpy, gc, color_magenta);
            Xutf8DrawString(dpy, switcher_popup, font_set, gc, text_x + offset_x + 3, text_y, title, strlen(title));
        }

        XSetForeground(dpy, gc, is_hovered ? color_sel_fg : color_fg);
        Xutf8DrawString(dpy, switcher_popup, font_set, gc, text_x + offset_x, text_y, title, strlen(title));
    }
    XFlush(dpy);
}

void draw_switcher(int is_new_activation) {
    if (switcher_popup == None || num_switcher == 0) return;

    int frames = is_new_activation ? 5 : 2;
    int delay = is_new_activation ? 12000 : 8000;
    for (int f = 0; f < frames; f++) {
        draw_grid_frame(1);
        usleep(delay);
    }
    draw_grid_frame(0);
}

void calculate_grid_tiles() {
    if (num_switcher <= 0) return;

    int cols = 1;
    while (cols * cols < num_switcher) cols++;
    int rows = (num_switcher + cols - 1) / cols;

    int margin = 40;
    int gap = 20;
    int avail_w = screen_width - (margin * 2) - (gap * (cols - 1));
    int avail_h = screen_height - (margin * 2) - (gap * (rows - 1));

    int tile_w = avail_w / cols;
    int tile_h = avail_h / rows;

    for (int i = 0; i < num_switcher; i++) {
        int r = i / cols;
        int c = i % cols;

        switcher_tiles[i].win = switcher_list[i];
        switcher_tiles[i].x = margin + c * (tile_w + gap);
        switcher_tiles[i].y = margin + r * (tile_h + gap);
        switcher_tiles[i].width = tile_w;
        switcher_tiles[i].height = tile_h;
    }
}

int get_tile_at_pos(int x, int y) {
    for (int i = 0; i < num_switcher; i++) {
        Tile *t = &switcher_tiles[i];
        if (x >= t->x && x <= t->x + t->width &&
            y >= t->y && y <= t->y + t->height) {
            return i;
        }
    }
    return -1;
}

void start_switcher() {
    if (switcher_active) return;

    num_switcher = 0;
    for (int i = 0; i < num_managed; i++) {
        XWindowAttributes attrs;
        if (XGetWindowAttributes(dpy, managed_windows[i], &attrs) && attrs.map_state == IsViewable) {
            switcher_list[num_switcher++] = managed_windows[i];
        }
    }
    if (num_switcher == 0) return;

    switcher_active = 1;
    switcher_index = 0;
    hovered_tile = -1;

    calculate_grid_tiles();

    XSetWindowAttributes attrs;
    attrs.override_redirect = True;
    attrs.background_pixel = color_bg;
    attrs.border_pixel = color_border;
    attrs.event_mask = StructureNotifyMask | ButtonPressMask | PointerMotionMask;

    switcher_popup = XCreateWindow(dpy, root, 0, 0, screen_width, screen_height, 0,
                                   CopyFromParent, InputOutput, CopyFromParent,
                                   CWOverrideRedirect | CWBackPixel | CWBorderPixel | CWEventMask, &attrs);

    XMapRaised(dpy, switcher_popup);
    
    XEvent ev;
    while (1) {
        XWindowEvent(dpy, switcher_popup, StructureNotifyMask, &ev);
        if (ev.type == MapNotify) break;
    }

    XGrabKeyboard(dpy, root, True, GrabModeAsync, GrabModeAsync, CurrentTime);
    XGrabPointer(dpy, switcher_popup, True, ButtonPressMask | PointerMotionMask,
                GrabModeAsync, GrabModeAsync, None, None, CurrentTime);

    // Initial mouse position check for hover
    Window r_win, c_win;
    int rx, ry, wx, wy;
    unsigned int mask;
    if (XQueryPointer(dpy, switcher_popup, &r_win, &c_win, &rx, &ry, &wx, &wy, &mask)) {
        hovered_tile = get_tile_at_pos(wx, wy);
    }

    draw_switcher(1);
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

    XEvent ev;
    while (1) {
        XWindowEvent(dpy, overlay, StructureNotifyMask, &ev);
        if (ev.type == MapNotify) break;
    }

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

void stop_switcher(int accept_index) {
    if (!switcher_active) return;

    XUngrabPointer(dpy, CurrentTime);
    XUngrabKeyboard(dpy, CurrentTime);
    XDestroyWindow(dpy, switcher_popup);
    switcher_popup = None;
    switcher_active = 0;

    if (accept_index >= 0 && accept_index < num_switcher) {
        Window target = switcher_tiles[accept_index].win;
        XRaiseWindow(dpy, target);
        XSetInputFocus(dpy, target, RevertToPointerRoot, CurrentTime);
        add_window(target);
        glitch_window(target);
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

    XGrabKey(dpy, tab_code, Mod1Mask, root, False, GrabModeAsync, GrabModeAsync);
    XGrabKey(dpy, tab_code, Mod1Mask | ShiftMask, root, False, GrabModeAsync, GrabModeAsync);

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
                                   (meta_r_code && (keys[meta_r_code >> 3] & (1 << (meta_r_code & 7))));
                    if (alt_down && !switcher_active) {
                        Window focused = None;
                        int revert_to;
                        XGetInputFocus(dpy, &focused, &revert_to);
                        if (focused != None && focused != root && focused != switcher_popup) {
                            ignore_unmap_window = focused;
                            XUnmapWindow(dpy, focused);
                            XMapWindow(dpy, focused);
                            XFlush(dpy);
                        }
                        start_switcher();
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
                if (!switcher_active || ev.xunmap.window != switcher_popup) {
                    remove_window(ev.xunmap.window);
                }
                if (num_managed == 0) XClearWindow(dpy, root);
                break;
            case DestroyNotify:
                if (!switcher_active || ev.xdestroywindow.window != switcher_popup) {
                    remove_window(ev.xdestroywindow.window);
                }
                if (num_managed == 0) XClearWindow(dpy, root);
                break;
            case MotionNotify: {
                if (switcher_active && ev.xmotion.window == switcher_popup) {
                    int prev_hovered = hovered_tile;
                    hovered_tile = get_tile_at_pos(ev.xmotion.x, ev.xmotion.y);
                    if (hovered_tile != prev_hovered) {
                        draw_grid_frame(0);
                    }
                }
                break;
            }
            case ButtonPress: {
                if (switcher_active && ev.xbutton.button == Button1) {
                    int clicked = get_tile_at_pos(ev.xbutton.x, ev.xbutton.y);
                    if (clicked != -1) {
                        stop_switcher(clicked);
                    }
                }
                break;
            }
            case KeyPress: {
                if (ev.xkey.keycode == tab_code) {
                    if (!switcher_active) {
                        start_switcher();
                    }
                    // IMPORTANT: If switcher IS active, extra Alt+Tab keypresses do NOTHING.
                    // Forced mouse selection!
                } else if (switcher_active && XLookupKeysym(&ev.xkey, 0) == XK_Escape) {
                    stop_switcher(-1);
                }
                break;
            }
            case KeyRelease: {
                // KeyRelease of Alt does NOT close the switcher anymore!
                // Mouse click or ESC is required to choose a window.
                break;
            }
        }
    }
    XCloseDisplay(dpy);
    return 0;
}

/*
==============================================================================
  ELISP CODE FOR YOUR ~/.emacs.d/init.el
==============================================================================
  Copiar el siguiente codigo en tu ~/.emacs.d/init.el:

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
          (call-process "xdotool" nil 0 nil "windowactivate" id)
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
  "Actualiza el buffer *External Windows* con las ventanas no-Emacs abiertas."
  (interactive)
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
          (insert "Presiona ENTER en cualquier línea para cambiar a esa ventana.\n\n")
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
                                                   (call-process "xdotool" nil 0 nil "windowactivate" id))))
                                     'window-id win-id
                                     'follow-link t)
                      (add-text-properties start (point) `(window-id ,win-id))
                      (insert "\n")))))
              (forward-line 1)))
          (goto-char (max (point-min) (min old-pos (point-max)))))))))

(defvar my-external-windows-thread nil
  "Hilo en segundo plano para actualizar las ventanas abiertas.")

(defun my-start-external-windows-tracker ()
  "Inicia el bucle infinito en un hilo de Emacs para rastrear las ventanas."
  (interactive)
  (unless (and my-external-windows-thread (thread-alive-p my-external-windows-thread))
    (setq my-external-windows-thread
          (make-thread
           (lambda ()
             (while t
               (ignore-errors (my-update-external-windows))
               (sleep-for 1)))
           "external-windows-tracker"))
    (message "Rastreador de ventanas externas iniciado.")))

(defun my-stop-external-windows-tracker ()
  "Detiene el rastreador de ventanas externas."
  (interactive)
  (when (and my-external-windows-thread (thread-alive-p my-external-windows-thread))
    (thread-signal my-external-windows-thread 'quit nil)
    (setq my-external-windows-thread nil)
    (message "Rastreador de ventanas externas detenido.")))

;; Iniciar automaticamente el rastreador al abrir Emacs:
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