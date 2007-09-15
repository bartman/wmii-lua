.PHONY: all luaixp luaeventloop clean tags install
all: luaixp luaeventloop

luaixp luaeventloop:
	${MAKE} -C $@

clean:
	-rm *~ */*~
	-${MAKE} -C luaixp clean
	-${MAKE} -C luaeventloop clean


cscope.files::
	find . -name '*.[ch]' -o -name '*.lua' | grep -v -e CVS -e SCCS > cscope.files

cscope.out: cscope.files
	-cscope -P`pwd` -b

tags: cscope.out
	rm -f tags
	xargs -n 50 ctags -a < cscope.files


install:
ifeq ($(shell pwd),$(wildcard ~/.wmii-3.5))
	@echo "You're already in the ~/wmii-3.5/ directory"
else
	mkdir -p ~/.wmii-3.5/core/ ~/.wmii-3.5/plugins/
	if test -f ~/.wmii-3.5/wmiirc ; then \
		cp wmiirc.lua ~/.wmii-3.5/wmiirc.dist ; \
		chmod +x ~/.wmii-3.5/wmiirc.dist ; \
	else \
		cp wmiirc.lua ~/.wmii-3.5/wmiirc ; \
		chmod +x ~/.wmii-3.5/wmiirc ; \
	fi
	cp plugins/*.lua ~/.wmii-3.5/plugins/
	${MAKE} -C luaixp install
	${MAKE} -C luaeventloop install
	# TODO: install manpage somewhere (~/usr/share/man/man3lua/ ?)
endif


man:
	pod2man \
		--name=wmii \
		--center="WMII Lua Integration" \
		--section=3lua \
		--release="wmii 3.6" \
		wmii.lua wmii.3lua
