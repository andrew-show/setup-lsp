include ../vars.mk

include $(TOPDIR)/rules.mk

post-install: $(DESTDIR)/bin/setup-lsp.sh

$(DESTDIR)/bin/setup-lsp.sh: setup-lsp.sh
	cp $< $@
