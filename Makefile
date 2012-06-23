PERL   = perl
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
SCRIPT = pp-cue2ddp.pl
SCRIPT_TEST = testsuite.pl

all:
	chmod 755 $(SCRIPT)

install:
	install -m 755 $(SCRIPT) $(BINDIR)

uninstall:
	rm $(BINDIR)/$(SCRIPT)

.PHONY: test
test:
	cd test; $(PERL) $(SCRIPT_TEST) all

clean:
	cd test; $(PERL) $(SCRIPT_TEST) clean
