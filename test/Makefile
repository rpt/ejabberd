.PHONY: all test

all: test

test_clean: escalus/ebin
	rm -rf tests/*.beam
	make test

test: escalus/ebin
	mkdir -p ct_report
	erlc -I escalus/deps/exmpp/include run_common_test.erl
	erl -noinput -sname test -setcookie ejabberd \
		-pa `pwd`/tests \
		-pa `pwd`/escalus/ebin \
		`pwd`/escalus/deps/exmpp/ebin -s run_common_test ct

escalus/ebin: escalus/Makefile
	(cd escalus; make)

escalus/Makefile:
	(cd ..; git submodule update --init)

console:
	erl -sname test -setcookie ejabberd \
		-pa `pwd`/tests \
		-pa `pwd`/escalus/ebin \
		`pwd`/escalus/deps/exmpp/ebin

.PHONY: escalus/ebin
