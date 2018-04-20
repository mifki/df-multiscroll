DFHACKVER ?= 0.44.05-r1

DFVERNUM = `echo $(DFHACKVER) | sed -e s/-.*// -e s/\\\\.//g`

DF ?= /Users/vit/Downloads/df_44_05_osx
DH ?= /Users/vit/Downloads/buildagent-2/workspace/root/dfhack/0.44
DHBUILD ?= build
DHLIB ?= $(DH)/$(DHBUILD)/library
ARCH ?= 64

SRC = multiscroll.mm
DEP = Makefile renderer_twbt.h

ifneq (,$(findstring 0.34,$(DFHACKVER)))
	EXT = so
else
	EXT = dylib
endif
OUT = dist/$(DFHACKVER)/multiscroll.plug.$(EXT)

INC = -I"$(DH)/library/include" -I"$(DH)/library/proto" -I"$(DH)/depends/protobuf" -I"$(DH)/depends/lua/include"
LIB = -L"$(DHLIB)" -ldfhack -ldfhack-version

CFLAGS = $(INC) -m$(ARCH) -DLINUX_BUILD -O3 -D_GLIBCXX_USE_CXX11_ABI=0
LDFLAGS = $(LIB) -shared

ifeq ($(shell uname -s), Darwin)
	CXX = clang -std=gnu++0x -stdlib=libstdc++ -ObjC++
	CFLAGS += -Wno-tautological-compare
	LDFLAGS += -framework AppKit -mmacosx-version-min=10.6 -undefined dynamic_lookup
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
