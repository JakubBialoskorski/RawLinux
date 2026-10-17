PREFIX = /usr

all:

install:
	install -D -m 755 pike $(DESTDIR)$(PREFIX)/bin/pike
	mkdir -p $(DESTDIR)$(PREFIX)/share/pike/recipes
	cp -R ../recipes/. $(DESTDIR)$(PREFIX)/share/pike/recipes/

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/pike
	rm -rf $(DESTDIR)$(PREFIX)/share/pike

check:
	shellcheck pike ../tests/run.sh
	../tests/run.sh

.PHONY: all install uninstall check
