.PHONY: check docs test e2e

check:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell vessel bin)/moc $(shell vessel sources) --check

all: check-strict docs test

check-strict:
	find src -type f -name '*.mo' -print0 | xargs -0 $(shell vessel bin)/moc $(shell vessel sources) -Werror --check
docs:
	$(shell vessel bin)/mo-doc

test:
	moc -r $(shell vessel sources) -wasi-system-api test/unit/Test.mo

e2e:
	./install-local.sh
	npm ci
	npm test

watch:
	while true; do \
		make $(WATCHMAKE); \
		inotifywait --exclude **/.vessel -qre close_write .; \
	done
