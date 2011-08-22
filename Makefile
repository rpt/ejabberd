.PHONY: rel deps test generate_snmp_header

all: deps compile

compile:
	./rebar compile

deps:
	./rebar get-deps

clean:
	./rebar clean

test:   
	(cd test; make)

eunit:
	./rebar skip_deps=true eunit

rel: deps
	./rebar compile generate

relclean:
	rm -rf rel/ejabberd
