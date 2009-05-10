# ------------------------------------------------------------------------
# default target

.PHONY: default
default: all

# ------------------------------------------------------------------------
# includes and defines

ifneq ($(MAKECMDGOALS),gitclean)
$(if $(wildcard config.mk),,$(shell cp config.mk.in config.mk))
include config.mk
endif
include Makefile.ext
include Makefile.check
include Makefile.rules

# ------------------------------------------------------------------------
# main targets

.PHONY: all help docs clean distclean gitclean tags

all clean distclean docs install install-user:
	@echo Running '$@' in src...
	${Q} ${MAKE} -C src $@

gitclean:
	@echo GITCLEAN
	$(if $(wildcard .git/config),,$(error this is not a git repository))
	${Q} git clean -d -x -f

# ------------------------------------------------------------------------
# help

help:
	@echo "make [target]"
	@echo
	@echo " general targets"
	@echo "   all              - build everything"
	@echo "   docs             - build documentation"
	@echo "   clean            - clean up build"
	@echo "   distclean        - clean even more"
	@echo "   gitclean         - clean everything not tracked by git"
	@echo "   install          - install in system dir"
	@echo "   install-user     - install in user home dir"
	@echo
	@echo " development targets"
	@echo "   tags             - build ctags/cscope index"
	@echo
	@${MAKE} -s ext-help

# ------------------------------------------------------------------------
# local dependencies for main rules

.PHONY: lcl-clean lcl-distclean

clean: lcl-clean
lcl-clean:
	-${Q} rm -f *~
	-${Q} rm -f cscope.files cscope.out tags

distclean: lcl-distclean
lcl-distclean: clean
	-${Q} rm -f config.mk

.PHONY: 

install: install-variable-check

install-user: install-user-variable-check

# ------------------------------------------------------------------------
# tags and cscope

.PHONY: cscope tags

cscope.files::
	${Q} find . -name '*.[ch]' -o -name '*.lua' | grep -v -e CVS -e SCCS > cscope.files

cscope: cscope.out
cscope.out: cscope.files
	-${Q} cscope -P`pwd` -b

tags: cscope.out
	${Q} rm -f tags
	${Q} xargs -n 50 ctags -a < cscope.files

