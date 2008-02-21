NAME         = yep
VERSION      = 0.0.6
DESTDIR      = /
PERL        ?= perl
PERLMODDIR   = $(shell $(PERL) -MConfig -e 'print $$Config{installvendorlib};')
YEP_SQLITE_DB = $(DESTDIR)/var/lib/YEP/db/yep.db
TEMPF = $(shell mktemp)

install_all: install install_conf install_db
	@echo "==========================================================="
	@echo "Append 'perl' to APACHE_MODULES an 'SSL' to APACHE_SERVER_FLAGS"
	@echo "in /etc/sysconfig/apache2 ."
	@echo "Required packages:"
	@echo "* apache2"
	@echo "* apache2-mod_perl"
	@echo "* mysql"
	@echo "* perl-DBI"
	@echo "* perl-DBD-mysql"
	@echo "* perl-Crypt-SSLeay"
	@echo "* perl-Config-IniFiles"
	@echo "* perl-XML-Parser"
	@echo "* perl-XML-Writer"
	@echo "* perl-libwww-perl"
	@echo "* perl-IO-Zlib"
	@echo "* perl-URI"
	@echo "* perl-TimeDate"
	@echo "* perl-Text-ASCIITable"
	@echo " "
	@echo "Finaly start the web server with 'rcapache2 start'"
	@echo "==========================================================="

install_db: install_db_mysql

install_db_sqlite:
	mkdir -p $(DESTDIR)/var/lib/YEP/db/
	cd db/
	sqlite3 -line $(YEP_SQLITE_DB) ".read db/yep-tables_sqlite.sql"
	sqlite3 -line $(YEP_SQLITE_DB) ".read db/products.sql"
	sqlite3 -line $(YEP_SQLITE_DB) ".read db/targets.sql"
	sqlite3 -line $(YEP_SQLITE_DB) ".read db/tmp-catalogs.sql"
	sqlite3 -line $(YEP_SQLITE_DB) ".read db/tmp-productcatalogs.sql"
	sqlite3 -line $(YEP_SQLITE_DB) ".read db/tmp-register.sql"
# this table is dropped
#	sqlite3 -line $(YEP_SQLITE_DB) ".read db/product_dependencies.sql"

install_db_mysql:
	echo "drop database if exists yep;" | mysql -u root
	echo "create database if not exists yep;" | mysql -u root
	cat db/yep-tables_mysql.sql | mysql -u root yep
	cat db/products.sql | mysql -u root yep
	cat db/targets.sql | mysql -u root yep
	cat db/tmp-catalogs.sql | mysql -u root yep
	cat db/tmp-productcatalogs.sql | mysql -u root yep
	cat db/tmp-register.sql | mysql -u root yep
# this table is dropped
#	cat db/product_dependencies.sql | mysql -u root yep

install_conf:
	mkdir -p $(DESTDIR)/etc/
	cp config/yep.conf $(DESTDIR)/etc/

install:
	mkdir -p $(DESTDIR)/usr/sbin/
	mkdir -p $(DESTDIR)/etc/apache2
	mkdir -p $(DESTDIR)/etc/yep.d/
	mkdir -p $(DESTDIR)/srv/www/htdocs/repo
	mkdir -p $(DESTDIR)/srv/www/htdocs/testing/repo
	mkdir -p $(DESTDIR)/srv/www/perl-lib/NU
	mkdir -p $(DESTDIR)/srv/www/perl-lib/YEP
	mkdir -p $(DESTDIR)$(PERLMODDIR)/YEP/Mirror
	mkdir -p $(DESTDIR)$(PERLMODDIR)/YEP/Parser
	cp apache2/yep-mod_perl-startup.pl $(DESTDIR)/etc/apache2/
	cp apache2/conf.d/*.conf $(DESTDIR)/etc/yep.d/
	cp apache2/vhosts.d/*.conf $(DESTDIR)/etc/yep.d/
	cp script/yep $(DESTDIR)/usr/sbin/
	cp script/yep-* $(DESTDIR)/usr/sbin/
	chmod 0755 $(DESTDIR)/usr/sbin/yep
	chmod 0755 $(DESTDIR)/usr/sbin/yep-*
	cp www/perl-lib/NU/*.pm $(DESTDIR)/srv/www/perl-lib/NU/
	cp www/perl-lib/YEP/Registration.pm $(DESTDIR)/srv/www/perl-lib/YEP/
	cp www/perl-lib/YEP/Utils.pm $(DESTDIR)$(PERLMODDIR)/YEP/
	cp www/perl-lib/YEP/NCCRegTools.pm $(DESTDIR)$(PERLMODDIR)/YEP/
	cp www/perl-lib/YEP/Mirror/*.pm /$(DESTDIR)$(PERLMODDIR)/YEP/Mirror/
	cp www/perl-lib/YEP/Parser/*.pm /$(DESTDIR)$(PERLMODDIR)/YEP/Parser/
	cp www/perl-lib/YEP/CLI.pm /$(DESTDIR)$(PERLMODDIR)/YEP/


test: clean
	cd tests; perl tests.pl && cd -

clean:
	find . -name "*~" -print0 | xargs -0 rm -f
	rm -rf tests/testdata/rpmmdtest/*
	rm -rf $(NAME)-$(VERSION)/
	rm -rf $(NAME)-$(VERSION).tar.bz2


dist: clean
	rm -rf $(NAME)-$(VERSION)/
	@mkdir -p $(NAME)-$(VERSION)/apache2/conf.d/
	@mkdir -p $(NAME)-$(VERSION)/apache2/vhosts.d/
	@mkdir -p $(NAME)-$(VERSION)/config
	@mkdir -p $(NAME)-$(VERSION)/db
	@mkdir -p $(NAME)-$(VERSION)/doc
	@mkdir -p $(NAME)-$(VERSION)/script
	@mkdir -p $(NAME)-$(VERSION)/tests/YEP/Mirror
	@mkdir -p $(NAME)-$(VERSION)/tests/testdata/jobtest
	@mkdir -p $(NAME)-$(VERSION)/tests/testdata/rpmmdtest
	@mkdir -p $(NAME)-$(VERSION)/tests/testdata/regdatatest
	@mkdir -p $(NAME)-$(VERSION)/www/perl-lib/NU
	@mkdir -p $(NAME)-$(VERSION)/www/perl-lib/YEP/Mirror
	@mkdir -p $(NAME)-$(VERSION)/www/perl-lib/YEP/Parser

	@cp apache2/*.pl $(NAME)-$(VERSION)/apache2/
	@cp apache2/conf.d/*.conf $(NAME)-$(VERSION)/apache2/conf.d/
	@cp apache2/vhosts.d/*.conf $(NAME)-$(VERSION)/apache2/vhosts.d/
	@cp config/yep.conf.production $(NAME)-$(VERSION)/config/yep.conf
	@cp db/*.sql $(NAME)-$(VERSION)/db/
	@cp db/*.sh $(NAME)-$(VERSION)/db/
	@cp db/README $(NAME)-$(VERSION)/db/
	@cp doc/* $(NAME)-$(VERSION)/doc/
	rm -f $(NAME)-$(VERSION)/doc/*~
	@cp tests/*.pl $(NAME)-$(VERSION)/tests/
	@cp tests/YEP/Mirror/*.pl $(NAME)-$(VERSION)/tests/YEP/Mirror/
	@cp -r tests/testdata/regdatatest/* $(NAME)-$(VERSION)/tests/testdata/regdatatest/
	@cp www/README $(NAME)-$(VERSION)/www/
	@cp script/* $(NAME)-$(VERSION)/script/
	@cp www/perl-lib/NU/*.pm $(NAME)-$(VERSION)/www/perl-lib/NU/
	@cp www/perl-lib/YEP/*.pm $(NAME)-$(VERSION)/www/perl-lib/YEP/
	@cp www/perl-lib/YEP/Mirror/*.pm $(NAME)-$(VERSION)/www/perl-lib/YEP/Mirror/
	@cp www/perl-lib/YEP/Parser/*.pm $(NAME)-$(VERSION)/www/perl-lib/YEP/Parser/
	@cp HACKING Makefile README COPYING $(NAME)-$(VERSION)/

	tar cfvj $(NAME)-$(VERSION).tar.bz2 $(NAME)-$(VERSION)/

pot:
	find www/ -name "*.pm" > sourcefiles
	find script/ -maxdepth 1 -name "yep*" >> sourcefiles
	xgettext --default-domain=yep --directory=. --keyword=__ -o yep.pot --files-from sourcefiles
	rm -f sourcefiles
