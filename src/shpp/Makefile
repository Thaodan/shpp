# general stuff
SHPP		= shpp
DESTDIR 	=
PREFIX 		= /usr/local
INSTALL 	= /usr/bin/install -D
MSGFMT 		= /usr/bin/msgfmtSED = /bin/sed
bindir 		= $(PREFIX)/bin
libdir 		= $(PREFIX)/lib
sysconfdir 	= $(PREFIX)/etc
# app specific  stuff
TARGET		= $(SHPP)
SHPP_VER	= 1.8
GIT_REV		= $(shell ../../tools/git_revgen)

all: $(TARGET)

$(TARGET): ${TARGET:=.in.sh}
	sed -e "s|@GITREV@|$(GIT_REV)|" \
		-e "s|@VER@|$(SHPP_VER)|"\
		shpp.in.sh > shpp
	chmod +x shpp

tests: 
	$(MAKE) -C $(@)
install: $(TARGET)
	$(INSTALL) -m755 $(<) $(bindir)/$(<)

clean:
	rm -f $(TARGET)


.PHONY: all install clean tests


