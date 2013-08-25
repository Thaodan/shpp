DESTDIR		   =
PREFIX		   = /usr
libdir		   = $(PREFIX)/lib
APPNAME		   = libsh
LIBSH_VER	   = 2.3
LIBSH_REV	   = 2230
INSTALL		   = /usr/bin/install
SCRIPTS		   = d_msg.in.sh  farray.in.sh  libsh.in.sh  shload.in.sh  test_input.in.sh 
TARGET		   = libsh
SHPP		   = shpp
override SHPPFLAGS += -DLIBSH_VER=$(LIBSH_VER) -DLIBSH_REV=$(LIBSH_REV) 
WDEBUG		= 0
DEBUG_DEFINES	= -DDEBUG_FARRAY_LESS_OUTPUT=y
ifneq ($(WDEBUG),0)
override SHPPFLAGS += $(DEBUG_DEFINES)
endif


all: $(TARGET)

$(TARGET): $(SCRIPTS) 
	$(SHPP)  $(SHPPFLAGS) $(@).in.sh -o $(@)


install:
	$(INSTALL) -Dm644 libsh $(libdir)/libsh




clean:
	rm -f $(TARGET)

.PHONY: all install clean

