.PHONY: all luaixp clean install
all: luaixp

luaixp:
	${MAKE} -C luaixp

clean:
	-rm *~
	-${MAKE} -C luaixp clean

install:
ifeq ($(shell pwd),$(wildcard ~/.wmii-3.5))
	@echo "You're already in the ~/wmii-3.5/ directory"
else
	mkdir -p ~/.wmii-3.5/core/ ~/.wmii-3.5/plugins/
	if test -f ~/.wmii-3.5/wmiirc ; then \
		cp wmiirc.lua ~/.wmii-3.5/wmiirc.dist ; \
		chmod +x ~/.wmii-3.5/wmiirc.dist ; \
	else ; \
		cp wmiirc.lua ~/.wmii-3.5/wmiirc ; \
		chmod +x ~/.wmii-3.5/wmiirc ; \
	end
	cp plugins/*.lua ~/.wmii-3.5/plugins/
	${MAKE} -C luaixp install
	# TODO: install manpage somewhere (~/usr/share/man/man3lua/ ?)
endif


man:
	pod2man \
		--name=wmii \
		--center="WMII Lua Integration" \
		--section=3lua \
		--release="wmii 3.6" \
		wmii.lua wmii.3lua
