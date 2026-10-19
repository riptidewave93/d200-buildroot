################################################################################
#
# d200-deck: the D200 key app (deckd)
#
################################################################################

D200_DECK_VERSION = 569a2991ba1a8a75d97b14a14ee99f5dbe1a9322
D200_DECK_SITE = $(call github,riptidewave93,d200-deck,$(D200_DECK_VERSION))
D200_DECK_LICENSE = GPL-3.0+, Apache-2.0 (icons), MIT (GitHub mark), BSD-3-Clause (Go modules)
D200_DECK_LICENSE_FILES = LICENSE NOTICE.md
D200_DECK_GOMOD = github.com/riptidewave93/d200-deck
D200_DECK_BUILD_TARGETS = cmd/deckd
D200_DECK_LDFLAGS = -s -w -X main.version=$(D200_DECK_VERSION)

define D200_DECK_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(D200_DECK_PKGDIR)/S60deckd $(TARGET_DIR)/etc/init.d/S60deckd
endef

$(eval $(golang-package))
