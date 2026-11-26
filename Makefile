.PHONY: build test app run clean

build:
	swift build

test:
	swift test

app:
	./Scripts/build-app.sh

run:
	./Scripts/build-app.sh --open

clean:
	swift package clean
	rm -rf dist
