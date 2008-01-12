include config.mk

MAN = wmii.3lua


# ------------------------------------------------------------------------
# main target

.PHONY: all help deb debi libs luaixp luaeventloop docs man clean tags install install-user install-variable-check install-user-variable-check
all: libs man

help:
	@echo "make [target]"
	@echo
	@echo " general targets"
	@echo "   all            - build everything"
	@echo "   libs           - build libraries"
	@echo "   docs           - build documentation"
	@echo "   clean          - clean up build"
	@echo "   install        - install in system dir"
	@echo "   install-user   - install in user home dir"
	@echo
	@echo " development targets"
	@echo "   tags           - build ctags index"
	@echo "   cscope         - build cscope index"
	@echo
	@echo " Debian targets"
	@echo "   deb            - build the .deb"
	@echo "   debi           - install the deb"

deb:
	debuild

debi: deb
	sudo debi

config.mk: config.mk.dist
	if test -f $@ ; then \
		touch $@ ; \
	else \
		cp $< $@ ; \
	fi

# ------------------------------------------------------------------------
# building

libs: luaeventloop luaixp
luaeventloop luaixp:
	${MAKE} -C $@

docs: man
man: ${MAN}
${MAN}: core/wmii.lua
	${POD2MAN} \
		--name=wmii \
		--center="WMII Lua Integration" \
		--section=3lua \
		--release="wmii 3.6" \
		$< $@

# ------------------------------------------------------------------------
# cleaning

clean:
	-rm -f *~ */*~
	-rm -f wmii.3lua
	-rm -f cscope.files cscope.out tags
	-${MAKE} -C luaixp clean
	-${MAKE} -C luaeventloop clean

# ------------------------------------------------------------------------
# installing

#
# install system wide
#
install: ${MAN} install-variable-check
	# create directories
	${INSTALL} -d ${ALL_INSTALL_DIRS}
	#
	# install libraries
	${MAKE} -C luaixp install
	${MAKE} -C luaeventloop install
	#
	# install core and plugin lua scripts
	${INSTALL} -m 0644 -t ${CORE_LUA_DIR} core/*.lua
	${INSTALL} -m 0644 -t ${PLUGIN_LUA_DIR} plugins/*.lua
	#
	# install new config file
	${INSTALL} -m 0755 -t ${RC_DIR} wmiirc.lua
	${INSTALL} -m 0644 -t ${XS_DIR} wmii-lua.desktop
	#
	# install man page
	${INSTALL} -m 0644 -t ${MAN_DIR} ${MAN}
	#
	# install scripts
	${INSTALL} -m 0755 -t ${BIN_DIR} install-wmiirc-lua
	${INSTALL} -m 0755 -t ${BIN_DIR} wmii-lua

install-variable-check:
	$(if ${ALL_INSTALL_DIRS},,$(error ALL_INSTALL_DIRS variable is empty; check config.mk))
	$(if ${CORE_LUA_DIR},,    $(error CORE_LUA_DIR variable is empty; check config.mk))
	$(if ${PLUGIN_LUA_DIR},,  $(error PLUGIN_LUA_DIR variable is empty; check config.mk))
	$(if ${RC_DIR},,          $(error RC_DIR variable is empty; check config.mk))
	$(if ${XS_DIR},,          $(error XS_DIR variable is empty; check config.mk))
	$(if ${MAN_DIR},,         $(error MAN_DIR variable is empty; check config.mk))
	$(if ${BIN_DIR},,         $(error BIN_DIR variable is empty; check config.mk))
	@echo Config vars OK.

#
# install in user directory
#
install-user: install-user-variable-check
ifeq ($(shell pwd),$(wildcard ~/.wmii-3.5))
	@echo "You're already in the ~/.wmii-3.5/ directory"
else
	${INSTALL} -d ${ALL_HOME_DIRS}
	@if test -f ${HOME_WMII}/wmiirc ; then \
		echo "NOTE: you might want to look at ${HOME_WMII}/wmiirc.dist" ; \
		${INSTALL} -T -m 0744 -b wmiirc.lua ${HOME_WMII}/wmiirc.dist ; \
	else \
		echo "Installing new ${HOME_WMII}/wmiirc" ; \
		${INSTALL} -T -m 0744 -b wmiirc.lua ${HOME_WMII}/wmiirc ; \
	fi
	${INSTALL} -m 0644 -b -t ${HOME_CORE} core/*.lua
	${INSTALL} -m 0644 -b -t ${HOME_PLUGINS} plugins/*.lua
	${INSTALL} -m 0644 -b -t ${HOME_WMII} ${MAN}
	${INSTALL} -m 0744 -t ${HOME_BIN_DIR} wmii-lua
	${MAKE} -C luaixp install-user
	${MAKE} -C luaeventloop install-user

install-user: ${MAN}
endif

install-user-variable-check:
	$(if ${ALL_HOME_DIRS},,$(error ALL_HOME_DIRS variable is empty; check config.mk))
	$(if ${HOME_WMII},,    $(error HOME_WMII variable is empty; check config.mk))
	$(if ${HOME_CORE},,    $(error HOME_CORE variable is empty; check config.mk))
	$(if ${HOME_PLUGINS},, $(error HOME_PLUGINS variable is empty; check config.mk))
	$(if ${HOME_WMII},,    $(error HOME_WMII variable is empty; check config.mk))
	$(if ${HOME_BIN_DIR},, $(error HOME_BIN_DIR variable is empty; check config.mk))
	@echo Config vars OK.

.PHONY: xxx
xxx:
	${MAKE} all
	sudo ${MAKE} install PREFIX=/usr


# ------------------------------------------------------------------------
# tags and cscope

cscope.files::
	find . -name '*.[ch]' -o -name '*.lua' | grep -v -e CVS -e SCCS > cscope.files

cscope.out: cscope.files
	-cscope -P`pwd` -b

tags: cscope.out
	rm -f tags
	xargs -n 50 ctags -a < cscope.files

