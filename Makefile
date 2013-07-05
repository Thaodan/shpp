# stub makefile will be updated later
include rules.mk
MODULES = src doc

all: $(MODULES)

$(MODULES): 
	$(MAKE) -C $(@)

clean install: 
	for target in $(MODULES) ; do $(MAKE) -C $$target $(@);done



.PHONY: clean install $(MODULES)
