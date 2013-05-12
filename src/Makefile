include ../rules.mk
DISTDIRS=shpp


all: $(DISTDIRS)

$(DISTDIRS):
	$(MAKE) -C $(@)

clean: 
	$(MAKE) -C shpp $(@)


install: $(DISTDIRS)
	$(MAKE) -C $(<) $(@)


.PHONY: all install clean $(DISTDIRS)
