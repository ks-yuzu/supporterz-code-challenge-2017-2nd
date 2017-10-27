start_server:
	perl -I './deps/lib/perl5' ./deps/bin/morbo level2.pl

test:
	prove -I './deps/lib/perl5'

test_without_prove:
	for i in `ls t/*.t`; do; perl -I './deps/lib/perl5' $i; done

rebuild_dependent_files:
	rm -rf deps && ./bin/cpanm --local-lib 'deps' --installdeps .

dump_all:
	@echo '[items]'
	@make --no-print-directory dump_items
	@echo
	@echo '[coupons]'
	@make --no-print-directory dump_coupons
	@echo
	@echo '[sets]'
	@make --no-print-directory dump_sets

dump_items:
	@echo 'select * from items;' | sqlite3 scc_lv2.sqlite | column -t -s'|'

dump_coupons:
	@echo 'select coupons.id, coupons.target_id, items.name, items.value, coupons.value, items.value + coupons.value from coupons inner join items on (coupons.target_id = items.id);' | sqlite3 scc_lv2.sqlite | column -t -s'|'

dump_sets:
	@echo 'select * from sets;' | sqlite3 scc_lv2.sqlite | column -t -s'|'

edit:
	emacsclient -n Makefile
