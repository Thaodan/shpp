TESTFILES	        =  $(shell find  ! -iname "*~" -type f -iname \*.sh)
TARGET		        =  ../shpp
TARGET_SHELL		=  
override TARGET_ARGS    += --stdout --errexit
all: $(TESTFILES)
$(TESTFILES): $(TARGET) 
	$(TARGET_SHELL) ./$(TARGET) $(TARGET_ARGS) $(@) 

$(TARGET): 
	$(MAKE) -C .. 

.PHONY: clean $(TESTFILES) 
