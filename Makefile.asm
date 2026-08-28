CC ?= gcc
STRIP ?= strip

TARGET = alt_tab_maximize_emacs_asm
SRC = alt_tab_maximize_emacs.s
OBJ = alt_tab_maximize_emacs.o

PREFIX ?= /usr/local

all: $(TARGET)

$(OBJ): $(SRC)
	gcc -c $(SRC) -o $(OBJ)

$(TARGET): $(OBJ)
	gcc -no-pie -s $(OBJ) -lX11 -o $(TARGET)
	chmod 755 $(TARGET)

clean:
	rm -f $(OBJ) $(TARGET)

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f $(TARGET) $(DESTDIR)$(PREFIX)/bin/
	chmod 755 $(DESTDIR)$(PREFIX)/bin/$(TARGET)

.PHONY: all clean install
