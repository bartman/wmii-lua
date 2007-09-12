.PHONY: all ixp clean install
all: ixp

ixp:
	${MAKE} -C ixp

clean:
	-rm *~
	-${MAKE} -C ixp clean

install:
	mkdir -p ~/.wmii-3.5/
	cp wmiirc.lua ~/.wmii-3.5/wmiirc
	cp wmii.lua ~/.wmii-3.5/wmii.lua
	chmod +x ~/.wmii-3.5/wmiirc
	${MAKE} -C ixp install
# TODO: install manpage somewhere

man:
	pod2man \
		--name=wmii \
		--center="WMII Lua Integration" \
		--section=3lua \
		--release="wmii 3.6" \
		wmii.lua wmii.3lua
