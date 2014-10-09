DFHACKVER ?= 0.40.13-r1

DFVERNUM = `echo $(DFHACKVER) | sed -e s/-r.*// -e s/\\\\.//g`

DF ?= /Users/vit/Downloads/df_40_13_osx
DH ?= /Users/vit/Downloads/dfhack-master

SRC = multiscroll.mm
DEP = Makefile

ifneq (,$(findstring 0.40,$(DFHACKVER)))
	EXT = dylib
else
	EXT = so
endif
OUT = dist/$(DFHACKVER)/multiscroll.plug.$(EXT)

INC = -I"$(DH)/library/include" -I"$(DH)/library/proto" -I"$(DH)/depends/protobuf" -I"$(DH)/depends/lua/include"
LIB = -L"$(DH)/build/library" -ldfhack

CFLAGS = $(INC) -m32 -DLINUX_BUILD -O3
LDFLAGS = $(LIB) -shared 

ifeq ($(shell uname -s), Darwin)
	CXX = c++ -std=gnu++0x -stdlib=libstdc++
	CFLAGS += -Wno-tautological-compare
	LDFLAGS += -framework AppKit -mmacosx-version-min=10.6
else
endif


all: $(OUT)

$(OUT): $(SRC) $(DEP)
	-@mkdir -p `dirname $(OUT)`
	$(CXX) $(SRC) -o $(OUT) -DDFHACK_VERSION=\"$(DFHACKVER)\" -DDF_$(DFVERNUM) $(CFLAGS) $(LDFLAGS)

inst: $(OUT)
	cp $(OUT) "$(DF)/hack/plugins/"

clean:
	-rm $(OUT)
