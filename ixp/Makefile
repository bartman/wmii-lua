SRCS = luaixp.c
OBJS = $(SRCS:.c=.o)

LUAINC := $(shell pkg-config --cflags lua5.1)
LUALIB := $(shell pkg-config --libs lua5.1)

IXPPREFIX = ${HOME}
IXPINC := -I${IXPPREFIX}/usr/include
IXPLIB := -L${IXPPREFIX}/usr/lib -lixp

CFLAGS += ${LUAINC} ${IXPINC} -ggdb -O0
LIBS   += ${LUALIB} ${IXPLIB}

TARGET = ixp.so

all: ${TARGET}

${TARGET}: ${OBJS}
	$(LD) -o $@ -shared $? $(LIBS)

${OBJS}: %.o: %.c Makefile
	${CC} -o $@ ${CFLAGS} -c $<

test: ${TARGET}
	./test.lua

clean:
	-rm -f ${TARGET} ${OBJS}
	-rm -f *.o *.so *~
