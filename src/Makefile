TOP         = ..
CONFIG_MK   = ${TOP}/config.mk

include ${CONFIG_MK}
include ${TOP}/Makefile.rules

MAN = wmii.3lua

# ------------------------------------------------------------------------
# main target

.PHONY: all help libs luaixp luaeventloop docs man clean distclean install install-user
all: libs man

help:
	@echo "make [target]"
	@echo
	@echo " general targets"
	@echo "   all            - build everything"
	@echo "   libs           - build libraries"
	@echo "   docs           - build documentation"
	@echo "   clean          - clean up build"
	@echo "   distclean      - clean even more"
	@echo "   install        - install in system dir"
	@echo "   install-user   - install in user home dir"
	@echo
	@echo " development targets"
	@echo "   tags           - build ctags index"
	@echo "   cscope         - build cscope index"

# ------------------------------------------------------------------------
# building

libs: luaeventloop luaixp
luaeventloop luaixp:
	${Q} ${MAKE} -C $@

docs: man
man: ${MAN}
${MAN}: core/wmii.lua
	${Q} ${POD2MAN} \
		--name=wmii \
		--center="WMII Lua Integration" \
		--section=3lua \
		--release="wmii 3.6" \
		$< $@

# ------------------------------------------------------------------------
# cleaning

clean:
	-${Q} rm -f *~ */*~
	-${Q} rm -f wmii.3lua
	-${Q} rm -f cscope.files cscope.out tags
	-${Q} ${MAKE} -C luaixp clean
	-${Q} ${MAKE} -C luaeventloop clean

distclean: clean

# ------------------------------------------------------------------------
# installing

#
# install system wide
#
install: ${MAN} install-variable-check
	# create directories
	${Q} ${INSTALL} -d ${ALL_INSTALL_DIRS}
	#
	# install libraries
	${Q} ${MAKE} -C luaixp install
	${Q} ${MAKE} -C luaeventloop install
	#
	# install core and plugin lua scripts
	${Q} ${INSTALL} -m 0644 -t ${CORE_LUA_DIR} core/*.lua
	${Q} ${INSTALL} -m 0644 -t ${PLUGIN_LUA_DIR} plugins/*.lua
	#
	# install new config file
	${Q} ${INSTALL} -m 0755 -t ${RC_DIR} wmiirc.lua
	${Q} ${INSTALL} -m 0644 -t ${XS_DIR} wmii-lua.desktop
	#
	# install man page
	${Q} ${INSTALL} -m 0644 -t ${MAN_DIR} ${MAN}
	#
	# install scripts
	${Q} ${INSTALL} -m 0755 -t ${BIN_DIR} install-wmiirc-lua
	${Q} ${INSTALL} -m 0755 -t ${BIN_DIR} wmii-lua

#
# install in user directory
#
install-user: install-user-variable-check
ifeq ($(shell pwd),$(wildcard ~/.wmii-3.5))
	@echo "You're already in the ~/.wmii-3.5/ directory"
else
	${Q} ${INSTALL} -d ${ALL_HOME_DIRS}
	${Q} if test -f ${HOME_WMII}/wmiirc ; then \
		echo "NOTE: you might want to look at ${HOME_WMII}/wmiirc.dist" ; \
		${INSTALL} -T -m 0744 -b wmiirc.lua ${HOME_WMII}/wmiirc.dist ; \
	else \
		echo "Installing new ${HOME_WMII}/wmiirc" ; \
		${INSTALL} -T -m 0744 -b wmiirc.lua ${HOME_WMII}/wmiirc ; \
	fi
	${Q} ${INSTALL} -m 0644 -b -t ${HOME_CORE} core/*.lua
	${Q} ${INSTALL} -m 0644 -b -t ${HOME_PLUGINS} plugins/*.lua
	${Q} ${INSTALL} -m 0644 -b -t ${HOME_WMII} ${MAN}
	${Q} ${INSTALL} -m 0744 -t ${HOME_BIN_DIR} wmii-lua
	${Q} ${MAKE} -C luaixp install-user
	${Q} ${MAKE} -C luaeventloop install-user

install-user: ${MAN}
endif


# ------------------------------------------------------------------------
# helpers from ${TOP} dir

.PHONY: install-variable-check install-user-variable-check tags cscope

${CONFIG_MK}:
	${Q} ${MAKE} -C $(dir ${CONFIG_MK}) $(notdir ${CONFIG_MK})

install-variable-check install-user-variable-check tags cscope:
	${Q} ${MAKE} -C ${TOP} $@

