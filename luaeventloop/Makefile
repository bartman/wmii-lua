SRCS = lel_main.c lel_debug.c lel_util.c lel_instance.c
OBJS = $(SRCS:.c=.o)

LUAINC := $(shell pkg-config --cflags lua5.1)
LUALIB := $(shell pkg-config --libs lua5.1)

CFLAGS += ${LUAINC} -ggdb -O0 -fPIC
LIBS   += ${LUALIB}

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
	mkdir -p ~/.wmii-3.5/ixp/
	cp ${TARGET} ~/.wmii-3.5/ixp/
