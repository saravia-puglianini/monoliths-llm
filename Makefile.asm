CC ?= as
LD ?= ld
STRIP ?= strip

TARGET = alt_tab_maximize_emacs_asm
SRC = alt_tab_maximize_emacs.s
OBJ = alt_tab_maximize_emacs.o

PREFIX ?= /usr/local
DYNAMIC_LINKER ?= /lib64/ld-linux-x86-64.so.2

all: $(TARGET)

$(OBJ): $(SRC)
	as $(SRC) -o $(OBJ)

$(TARGET): $(OBJ)
	ld -O1 --gc-sections -z norelro --build-id=none -s $(OBJ) -lX11 -dynamic-linker $(DYNAMIC_LINKER) -o $(TARGET)
	chmod 755 $(TARGET)

clean:
	rm -f $(OBJ) $(TARGET)

install: all
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f $(TARGET) $(DESTDIR)$(PREFIX)/bin/
	chmod 755 $(DESTDIR)$(PREFIX)/bin/$(TARGET)

.PHONY: all clean install
