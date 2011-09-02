.PHONY: all test show_test_results

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

show_test_results:
	$$BROWSER `ls -td ct_report/ct_run.test@*/index.html | head -n 1` &

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
