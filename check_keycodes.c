#include <stdio.h>
#include <X11/Xlib.h>
#include <X11/keysym.h>

int main() {
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        printf("Cannot open display\n");
        return 1;
    }
    printf("Display opened successfully\n");

    char keys[] = {'1', '2', '3', '4', '5', '6', '8', '9', 'b', 'r', 'p', 'l', 'q', 'w', 'e', 'a', 's', 'd', 'z', 'x', 'c', 'y', 'f', 'j', 'u', 'm', 'g', 'o'};
    for (int i = 0; i < sizeof(keys); i++) {
        KeyCode kc = XKeysymToKeycode(display, keys[i]);
        printf("Key '%c' -> KeyCode %d\n", keys[i], (int)kc);
    }

    KeySym syms[] = {
        XStringToKeysym("XF86AudioLowerVolume"),
        XStringToKeysym("XF86AudioRaiseVolume"),
        XStringToKeysym("XF86AudioMute"),
        XStringToKeysym("XF86MonBrightnessDown"),
        XStringToKeysym("XF86MonBrightnessUp"),
        XStringToKeysym("XF86PowerOff"),
        XStringToKeysym("XF86TouchpadToggle")
    };
    const char *names[] = {
        "XF86AudioLowerVolume",
        "XF86AudioRaiseVolume",
        "XF86AudioMute",
        "XF86MonBrightnessDown",
        "XF86MonBrightnessUp",
        "XF86PowerOff",
        "XF86TouchpadToggle"
    };
    for (int i = 0; i < 7; i++) {
        KeyCode kc = XKeysymToKeycode(display, syms[i]);
        printf("Sym '%s' -> KeyCode %d\n", names[i], (int)kc);
    }

    XCloseDisplay(display);
    return 0;
}
