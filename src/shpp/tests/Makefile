TESTFILES	        =  $(shell find  ! -iname "*~" -type f -iname \*.sh)
TARGET		        =  ../shpp
override TARGET_ARGS    += --stdout --errexit
all: $(TESTFILES)
$(TESTFILES): $(TARGET) 
	./$(TARGET) $(TARGET_ARGS) $(@) 

$(TARGET): 
	$(MAKE) -C .. 

.PHONY: clean $(TESTFILES) 
