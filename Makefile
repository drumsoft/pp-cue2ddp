
all: chmod

chmod:
	chmod a+x pp-cue2ddp.pl test/testsuite.pl

.PHONY: test
test:
	cd test; ./testsuite.pl all

clean:
	cd test; ./testsuite.pl clean
