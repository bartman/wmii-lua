TOP         = ../..
CONFIG_MK   = ${TOP}/config.mk
include ${CONFIG_MK}
include ${TOP}/Makefile.rules

SRCS = lixp_main.c lixp_debug.c lixp_util.c lixp_instance.c
OBJS = $(SRCS:.c=.o)

CFLAGS += ${LUA_INC} ${IXP_INC} -ggdb -O0 -fPIC
LIBS   += ${LUA_LIB} ${IXP_LIB}

#CFLAGS += -DDBG

TARGET = ixp.so

.PHONY: all test clean install
all: ${TARGET}

${TARGET}: ${OBJS}
	@echo "  LINK $@"
	${Q} $(CC) ${CFLAGS} -o $@ -shared $^ $(LIBS)

${OBJS}: %.o: %.c Makefile
	@echo "  CC $@"
	${Q} ${CC} ${CFLAGS} -o $@ -c $<

test: ${TARGET}
	./test.lua

clean:
	-${Q} rm -f ${TARGET} ${OBJS}
	-${Q} rm -f *.o *.so *~

install: ${TARGET}
	${Q} ${INSTALL} -d ${CORE_LIB_DIR}
	${Q} ${INSTALL} -b -t ${CORE_LIB_DIR} ${TARGET}

install-user: ${TARGET}
	${Q} ${INSTALL} -d ${HOME_CORE}
	${Q} ${INSTALL} -m 0744 -b -t ${HOME_CORE} ${TARGET}
