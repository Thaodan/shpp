RESULT_STABLE	= verified.cache
RESULT_CURRENT	= test.cache
LATEST_TAG	:= $(shell git describe --abbrev=0 --tags)
CURRENT_REV	:= $(shell git rev-parse --abbrev-ref HEAD)
DIFF		= diff -urq
all: check

stdout: RESULT_STABLE=0
stdout:	RESULT_CURRENT=0
stdout: all

latest_tag:
	git checkout $(LATEST_TAG)
current:
	git checkout $(CURRENT_REV)

tests_stable: latest_tag
	make -f tests.mk RESULT=$(RESULT_STABLE)
tests: current
	make -f tests.mk RESULT=$(RESULT_CURRENT)
check: tests_stable tests
	$(DIFF) $(RESULT_STABLE) $(RESULT_CURRENT)

clean:
	make -f tests.mk RESULT=$(RESULT_CURRENT) clean
	make -f tests.mk RESULT=$(RESULT_STABLE) clean

.PHONY: clean $(TESTFILES) $(TARGET) stdout
.NOTPARALLEL: latest_tag current check tests tests_stable
