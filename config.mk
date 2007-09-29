# ------------------------------------------------------------------------
LUA_VERSION	= 5.1

CC = cc
INSTALL = install
POD2MAN = pod2man

# ------------------------------------------------------------------------
# system directories

DESTDIR		=
PREFIX		= /usr/local

CORE_LIB_DIR	= ${DESTDIR}${PREFIX}/lib/lua/${LUA_VERSION}
CORE_LUA_DIR	= ${DESTDIR}${PREFIX}/share/lua/${LUA_VERSION}

PLUGIN_LIB_DIR	= ${DESTDIR}${PREFIX}/lib/lua/${LUA_VERSION}/wmii
PLUGIN_LUA_DIR	= ${DESTDIR}${PREFIX}/share/lua/${LUA_VERSION}/wmii

BIN_DIR		= ${DESTDIR}${PREFIX}/bin
RC_DIR		= ${DESTDIR}/etc/X11/wmii-3.5
MAN_DIR		= ${DESTDIR}${PREFIX}/share/man/man3
XS_DIR		= ${DESTDIR}${PREFIX}/share/xsessions

ALL_INSTALL_DIRS= ${CORE_LIB_DIR} \
		  ${CORE_LUA_DIR} \
		  ${PLUGIN_LIB_DIR} \
		  ${PLUGIN_LUA_DIR} \
		  ${BIN_DIR} \
		  ${RC_DIR} \
		  ${MAN_DIR} \
		  ${XS_DIR}

# ------------------------------------------------------------------------
# home directories

HOME_WMII	= ~/.wmii-3.5
HOME_CORE	= ${HOME_WMII}/core
HOME_PLUGINS	= ${HOME_WMII}/plugins

ALL_HOME_DIRS	= ${HOME_CORE} \
		  ${HOME_PLUGINS}

