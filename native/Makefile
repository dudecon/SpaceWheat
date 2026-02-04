CXX = g++
CXXFLAGS = -std=c++17 -fPIC -O2 -march=x86-64 \
           -I./include \
           -I./include/godot_cpp \
           -I./include/gdextension \
           -DLINUX_ENABLED -DUNIX_ENABLED -DGDEXTENSION

LDFLAGS = -shared ./lib/libgodot-cpp.linux.template_release.x86_64.a

SOURCES = $(wildcard src/*.cpp)
OBJECTS = $(SOURCES:.cpp=.o)
TARGET = bin/libquantummatrix.linux.template_release.x86_64.so

all: $(TARGET)

$(TARGET): | bin

bin:
	mkdir -p bin

$(TARGET): $(OBJECTS)
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)
	@cd bin && ln -sf libquantummatrix.linux.template_release.x86_64.so libquantummatrix.linux.template_debug.x86_64.so
	@echo ""
	@echo "✓ Build complete: $(TARGET)"
	@ls -lh bin/*.so

%.o: %.cpp
	@echo "Compiling $<..."
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f src/*.o bin/*.so

.PHONY: all clean
