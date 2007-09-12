SRCS = luaixp.c debug.c
OBJS = $(SRCS:.c=.o)

LUAINC := $(shell pkg-config --cflags lua5.1)
LUALIB := $(shell pkg-config --libs lua5.1)

IXPPREFIX = ${HOME}
IXPINC := -I${IXPPREFIX}/usr/include
IXPLIB := -L${IXPPREFIX}/usr/lib -lixp

CFLAGS += ${LUAINC} ${IXPINC} -ggdb -O0 -fPIC
LIBS   += ${LUALIB} ${IXPLIB}

TARGET = ixp.so

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
	mkdir -p ~/.wmii-3.5/ixp/
	cp ${TARGET} ~/.wmii-3.5/ixp/
