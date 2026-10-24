.PHONY: dev test analyze format build-apk clean gen

gen:
	dart run build_runner build --delete-conflicting-outputs

analyze:
	dart analyze --fatal-infos

format:
	dart format .

test:
	flutter test

test-coverage:
	flutter test --coverage

build-apk:
	flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info

clean:
	flutter clean && rm -rf build coverage

dev:
	flutter run
