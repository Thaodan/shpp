include ../rules.mk
# app specific  stuff
TARGET		= shpp
SHPP_VER	= 1.9
GIT_REV		= $(shell ../tools/git_revgen)

all: $(TARGET)

$(TARGET): ${TARGET:=.in.sh}
	sed -e "s|@GITREV@|$(GIT_REV)|" \
		-e "s|@VER@|$(SHPP_VER)|"\
		shpp.in.sh > shpp
	chmod +x shpp

tests: $(TARGET)
	$(MAKE) -C $(@)
install: $(TARGET)
	$(INSTALL) -m755 $(<) $(bindir)/$(<)

clean:
	rm -f $(TARGET)


.PHONY: all install clean tests


