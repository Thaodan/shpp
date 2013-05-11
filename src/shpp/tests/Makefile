TESTFILES	= $(shell find  ! -iname "*~" -type f -iname \*.sh)
TARGET		= ../shpp

all: $(TESTFILES)
$(TESTFILES): $(TARGET) 
	./$(TARGET) --stdout --errexit $(@) 

$(TARGET): 
	$(MAKE) -C .. 

.PHONY: clean $(TESTFILES) 
