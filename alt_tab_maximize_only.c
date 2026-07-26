#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_WINDOWS 1000

Display *dpy;
Window root;
int screen, screen_width, screen_height;

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
XFontStruct *font_info;
GC gc;

unsigned long get_color(const char *name) {
    Colormap cmap = DefaultColormap(dpy, screen);
    XColor color;
    return (XParseColor(dpy, cmap, name, &color) && XAllocColor(dpy, cmap, &color)) ? color.pixel : BlackPixel(dpy, screen);
}

void init_colors() {
    color_bg = get_color("#16161a");
    color_fg = get_color("#ecefe4");
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
    return (XGetWindowAttributes(dpy, w, &attrs) && !attrs.override_redirect);
}

void maximize_window(Window w) {
    if (is_manageable(w)) {
        XMoveResizeWindow(dpy, w, 0, 0, screen_width, screen_height);
        XSetWindowBorderWidth(dpy, w, 0);
    }
}

void draw_glitch_frame(int popup_width, int popup_height, int is_transition) {
    XSetForeground(dpy, gc, is_transition ? ((rand() % 3 == 0) ? color_magenta : color_bg) : color_bg);
    XFillRectangle(dpy, switcher_popup, gc, 0, 0, popup_width, popup_height);

    int item_height = font_info->ascent + font_info->descent + 10;
    int y_offset = 15;

    if (is_transition || (rand() % 4 == 0)) {
        int lines = is_transition ? (5 + (rand() % 10)) : 2;
        for (int i = 0; i < lines; i++) {
            XSetForeground(dpy, gc, (rand() % 2) ? color_cyan : color_magenta);
            XFillRectangle(dpy, switcher_popup, gc, rand() % 50, rand() % popup_height,
                           50 + (rand() % (popup_width - 50)), 1 + (rand() % (is_transition ? 15 : 4)));
        }
    }

    for (int i = 0; i < num_switcher; i++) {
        char title[256];
        get_window_title(switcher_list[i], title, sizeof(title));
        int text_y = y_offset + i * item_height + font_info->ascent + 5;
        int text_x = 20;

        int glitch_this = is_transition || (rand() % 8 == 0);
        int offset_x = glitch_this ? (rand() % 11 - 5) : 0;
        
        if (glitch_this && strlen(title) > 2) {
            int glitch_chars = 1 + (rand() % 3);
            for (int g = 0; g < glitch_chars; g++) {
                title[rand() % strlen(title)] = "X#_$%&!01"[rand() % 9];
            }
        }

        if (i == switcher_index) {
            XSetForeground(dpy, gc, color_sel_bg);
            XFillRectangle(dpy, switcher_popup, gc, 10, y_offset + i * item_height, popup_width - 20, item_height);
            XSetForeground(dpy, gc, color_sel_fg);
        } else {
            XSetForeground(dpy, gc, color_fg);
        }

        if (glitch_this) {
            XSetForeground(dpy, gc, color_cyan);
            XDrawString(dpy, switcher_popup, gc, text_x + offset_x - 3, text_y, title, strlen(title));
            XSetForeground(dpy, gc, color_magenta);
            XDrawString(dpy, switcher_popup, gc, text_x + offset_x + 3, text_y, title, strlen(title));
        }

        XSetForeground(dpy, gc, (i == switcher_index) ? color_sel_fg : color_fg);
        XDrawString(dpy, switcher_popup, gc, text_x + offset_x, text_y, title, strlen(title));
    }
    XFlush(dpy);
}

void draw_switcher(int is_new_activation) {
    if (switcher_popup == None || num_switcher == 0) return;

    int item_height = font_info->ascent + font_info->descent + 10;
    int popup_width = 500;
    int popup_height = num_switcher * item_height + 30;

    int frames = is_new_activation ? 6 : 3;
    int delay = is_new_activation ? 18000 : 12000;
    for (int f = 0; f < frames; f++) {
        draw_glitch_frame(popup_width, popup_height, 1);
        usleep(delay);
    }
    draw_glitch_frame(popup_width, popup_height, 0);
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
    switcher_index = (num_switcher > 1) ? 1 : 0;

    int item_height = font_info->ascent + font_info->descent + 10;
    int popup_width = 500;
    int popup_height = num_switcher * item_height + 30;

    XSetWindowAttributes attrs;
    attrs.override_redirect = True;
    attrs.background_pixel = color_bg;
    attrs.border_pixel = color_border;
    attrs.event_mask = StructureNotifyMask;

    switcher_popup = XCreateWindow(dpy, root, (screen_width - popup_width) / 2, (screen_height - popup_height) / 2,
                                   popup_width, popup_height, 2, CopyFromParent, InputOutput, CopyFromParent,
                                   CWOverrideRedirect | CWBackPixel | CWBorderPixel | CWEventMask, &attrs);

    XMapRaised(dpy, switcher_popup);
    
    XEvent ev;
    while (1) {
        XWindowEvent(dpy, switcher_popup, StructureNotifyMask, &ev);
        if (ev.type == MapNotify) break;
    }

    XGrabKeyboard(dpy, root, True, GrabModeAsync, GrabModeAsync, CurrentTime);
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

void stop_switcher(int accept) {
    if (!switcher_active) return;

    XUngrabKeyboard(dpy, CurrentTime);
    XDestroyWindow(dpy, switcher_popup);
    switcher_popup = None;
    switcher_active = 0;

    if (accept && num_switcher > 0 && switcher_index >= 0 && switcher_index < num_switcher) {
        Window target = switcher_list[switcher_index];
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

    font_info = XLoadQueryFont(dpy, "-*-liberation sans-medium-r-normal--14-*-*-*-*-*-*-*");
    if (!font_info) font_info = XLoadQueryFont(dpy, "fixed");
    if (!font_info) return 1;

    init_colors();

    gc = XCreateGC(dpy, root, 0, NULL);
    XSetFont(dpy, gc, font_info->fid);

    XSelectInput(dpy, root, SubstructureRedirectMask | SubstructureNotifyMask | KeyPressMask | KeyReleaseMask);

    KeyCode tab_code = XKeysymToKeycode(dpy, XK_Tab);
    XGrabKey(dpy, tab_code, Mod1Mask, root, True, GrabModeAsync, GrabModeAsync);
    XGrabKey(dpy, tab_code, Mod1Mask | ShiftMask, root, True, GrabModeAsync, GrabModeAsync);

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
            case KeyPress: {
                if (ev.xkey.keycode == tab_code) {
                    if (!switcher_active) {
                        start_switcher();
                    } else {
                        switcher_index = (ev.xkey.state & ShiftMask) ? 
                            (switcher_index - 1 + num_switcher) % num_switcher : 
                            (switcher_index + 1) % num_switcher;
                        draw_switcher(0);
                    }
                } else if (switcher_active && XLookupKeysym(&ev.xkey, 0) == XK_Escape) {
                    stop_switcher(0);
                }
                break;
            }
            case KeyRelease: {
                if (switcher_active) {
                    KeySym sym = XLookupKeysym(&ev.xkey, 0);
                    if (sym == XK_Alt_L || sym == XK_Alt_R || sym == XK_Meta_L || sym == XK_Meta_R) {
                        stop_switcher(1);
                    }
                }
                break;
            }
        }
    }
    XCloseDisplay(dpy);
    return 0;
}

/*
  Do a folder
  ~/alt_tab_maximize_only/Makefile
  ~/alt_tab_maximize_only/alt_tab_maximize_only.c
  ~/alt_tab_maximize_only/alt_tab_maximize_only-session
*/

/*

# DO A Makefile

       CC = gcc
       CFLAGS = -Wall -Wextra -Ofast -flto -s -fno-asynchronous-unwind-tables -fno-ident
       LIBS = -lX11
       PREFIX ?= /usr/local

       all: alt_tab_maximize_only

       alt_tab_maximize_only: alt_tab_maximize_only.c
	       $(CC) $(CFLAGS) -o alt_tab_maximize_only alt_tab_maximize_only.c $(LIBS)
	       chmod +x alt_tab_maximize_only alt_tab_maximize_only-session

       install: all
	       mkdir -p $(DESTDIR)$(PREFIX)/bin
	       cp -f alt_tab_maximize_only $(DESTDIR)$(PREFIX)/bin
	       cp -f alt_tab_maximize_only-session $(DESTDIR)$(PREFIX)/bin
		      chmod 755 $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_only
	      chmod 755 $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_only-session

      uninstall:
	      rm -f $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_only
	      rm -f $(DESTDIR)$(PREFIX)/bin/alt_tab_maximize_only-session

      clean:
	      rm -f alt_tab_maximize_only

*/

/*
# DO A file ~/alt_tab_maximize_only/alt_tab_maximize_only-session with:

      #!/bin/sh
      # Session wrapper for alt_tab_maximize_only window manager

      # If alt_tab_maximize_only is in the same directory, run it, otherwise assume it's in the PATH
      if [ -x "$(dirname "$0")/alt_tab_maximize_only" ]; then
	  exec "$(dirname "$0")/alt_tab_maximize_only"
      else
	  exec alt_tab_maximize_only
      fi

*/