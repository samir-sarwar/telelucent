APP     = Telelucent
MIN_OS  = 12.0
BUILD   = build
BUNDLE  = $(BUILD)/$(APP).app
SOURCES = $(wildcard Sources/*.swift)
FLAGS   = -Osize -wmo -swift-version 5 -Xlinker -dead_strip

.PHONY: all run install release clean icon

all: $(BUNDLE)

# One slice per architecture, glued together with lipo below.
$(BUILD)/%/$(APP): $(SOURCES)
	@mkdir -p $(@D)
	swiftc $(FLAGS) -target $*-apple-macos$(MIN_OS) $(SOURCES) -o $@
	strip -x $@

$(BUNDLE): $(BUILD)/arm64/$(APP) $(BUILD)/x86_64/$(APP) Resources/Info.plist Resources/AppIcon.icns
	@rm -rf $@
	@mkdir -p $@/Contents/MacOS $@/Contents/Resources
	lipo -create $(BUILD)/arm64/$(APP) $(BUILD)/x86_64/$(APP) -output $@/Contents/MacOS/$(APP)
	cp Resources/Info.plist $@/Contents/
	cp Resources/AppIcon.icns $@/Contents/Resources/
	codesign --force --sign - $@

run: $(BUNDLE)
	-@pkill -x $(APP); sleep 0.3
	open $(BUNDLE)

install: $(BUNDLE)
	-@pkill -x $(APP); sleep 0.3
	rm -rf /Applications/$(APP).app
	cp -R $(BUNDLE) /Applications/
	open /Applications/$(APP).app

# Zipped app for GitHub releases.
release: clean $(BUNDLE)
	cd $(BUILD) && ditto -c -k --sequesterRsrc --keepParent $(APP).app $(APP).zip
	@ls -lh $(BUILD)/$(APP).zip | awk '{print "$(BUILD)/$(APP).zip", $$5}'

icon:
	swift scripts/make-icon.swift .

clean:
	rm -rf $(BUILD)
