# ------------------------------------------------------------------------
# default target

.PHONY: default
default: all

# ------------------------------------------------------------------------
# includes and defines

include config.mk
include Makefile.check

# ------------------------------------------------------------------------
# main targets

.PHONY: all help docs clean distclean tags

all clean distclean docs install install-user:
	${MAKE} -C src $@

help:
	@echo "make [target]"
	@echo
	@echo " general targets"
	@echo "   all            - build everything"
	@echo "   docs           - build documentation"
	@echo "   clean          - clean up build"
	@echo "   distclean      - clean even more"
	@echo "   install        - install in system dir"
	@echo "   install-user   - install in user home dir"
	@echo
	@echo " development targets"
	@echo "   tags           - build ctags/cscope index"

config.mk: config.mk.dist
	if test -f $@ ; then \
		touch $@ ; \
	else \
		cp $< $@ ; \
	fi

# ------------------------------------------------------------------------
# local dependencies for main rules

.PHONY: lcl-clean lcl-distclean

clean: lcl-clean
lcl-clean:
	-rm -f *~ */*~
	-rm -f cscope.files cscope.out tags

distclean: lcl-distclean
lcl-distclean: clean
	-rm -f config.mk

.PHONY: 

install: install-variable-check

install-user: install-user-variable-check

# ------------------------------------------------------------------------
# tags and cscope

.PHONY: cscope tags

cscope.files::
	find . -name '*.[ch]' -o -name '*.lua' | grep -v -e CVS -e SCCS > cscope.files

cscope: cscope.out
cscope.out: cscope.files
	-cscope -P`pwd` -b

tags: cscope.out
	rm -f tags
	xargs -n 50 ctags -a < cscope.files

