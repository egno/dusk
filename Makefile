APP := build/Dusk.app
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')

.PHONY: build test app install run clean

build:
	swift build

test:
	swift test

app:
	scripts/bundle.sh $(VERSION)

# Replaces /Applications/Dusk.app with a fresh build and starts it.
install: app
	-pkill -x Dusk; while pgrep -x Dusk >/dev/null; do sleep 0.2; done
	rm -rf /Applications/Dusk.app
	cp -R $(APP) /Applications/Dusk.app
	open /Applications/Dusk.app

run: build
	swift run Dusk

clean:
	rm -rf .build build dist
