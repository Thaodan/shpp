TESTFILES	        =  $(wildcard *.sh)
TARGET		        =  ./../shpp
TARGET_SHELL		=  
override TARGET_ARGS    +=  --stdout --errexit
RESULT 			=

all: $(TESTFILES)

$(RESULT):
	mkdir $(RESULT)
$(TESTFILES): $(TARGET) $(RESULT)
	$(TARGET_SHELL) $(TARGET) $(TARGET_ARGS) $(@)  > \
	$(RESULT)/$(@)

$(TARGET): 
	$(MAKE) -C .. 
clean:
	rm -rf $(RESULT)

.PHONY: clean $(TESTFILES) $(TARGET)
