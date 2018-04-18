TARGET = i686-w64-mingw32
include iup/Makefile

WINDOWS_LIBS = -lgdi32 -lcomdlg32 -lcomctl32 -luuid -loleaut32 -lole32
SRC = nsfe-editor.c
EXE = nsfe-editor

all: $(EXE)-installer.exe

$(EXE)-installer.exe: $(EXE).exe $(EXE).nsi
	makensis $(EXE).nsi

$(EXE).exe: $(SRC) $(LIBIUPLUA) $(LIBIUP) $(LIBLUA) $(EXE).res $(EXE).lh
	$(TARGET_CC) -mwindows -static -I$(LUA_INCDIR) -I$(IUP_INCDIR) -o $(EXE).exe.tmp $(SRC) $(LIBIUPLUA) $(LIBIUP) $(LIBLUA) \
	$(WINDOWS_LIBS) $(EXE).res
	$(TARGET_STRIP) $(EXE).exe.tmp
	upx $(EXE).exe.tmp
	mv $(EXE).exe.tmp $(EXE).exe

$(EXE).res: $(EXE).rc $(LIBIUP)
	$(TARGET_WINDRES) $(EXE).rc -O coff -o $(EXE).res

$(EXE).lh: $(EXE).lua
	luajit tools/bin2c.lua $(EXE).lua > $(EXE).lh

clean:
	make -C iup clean
	rm -f $(EXE).exe $(EXE).res $(EXE).lh $(EXE)-installer.exe
