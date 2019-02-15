TESTFILES	        =  $(wildcard *.sh)
TARGET		        =  ./../shpp
TARGET_SHELL		=  
override TARGET_ARGS    +=  --stdout --errexit
RESULT 			= 0
ifneq ($(RESULT),0)
	RESULT_STR=> $(RESULT)/$(@) 2>&1
endif

all: $(TESTFILES)

$(RESULT):
	mkdir $(RESULT)
$(TESTFILES): $(TARGET) $(RESULT)
	$(TARGET_SHELL) $(TARGET) $(TARGET_ARGS) $(@) $(RESULT_STR)

$(TARGET): 
	$(MAKE) -C .. 
clean:
	rm -rf $(RESULT)

.PHONY: clean $(TESTFILES) $(TARGET)
