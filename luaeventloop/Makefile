include ../config.mk

SRCS = lel_main.c lel_debug.c lel_util.c lel_instance.c
OBJS = $(SRCS:.c=.o)

CFLAGS += ${LUA_INC} -ggdb -O0 -fPIC
LIBS   += ${LUA_LIB}

#CFLAGS += -DDBG

TARGET = eventloop.so

.PHONY: all test clean install
all: ${TARGET}

${TARGET}: ${OBJS}
	$(CC) ${CFLAGS} -o $@ -shared $^ $(LIBS)

${OBJS}: %.o: %.c Makefile
	${CC} ${CFLAGS} -o $@ -c $<

test: ${TARGET}
	./test.lua

clean:
	-rm -f ${TARGET} ${OBJS}
	-rm -f *.o *.so *~

install: ${TARGET}
	${INSTALL} -d ${CORE_LIB_DIR}
	${INSTALL} -b -t ${CORE_LIB_DIR} ${TARGET}

install-user: ${TARGET}
	${INSTALL} -d ${HOME_CORE}
	${INSTALL} -m 0744 -b -t ${HOME_CORE} ${TARGET}
