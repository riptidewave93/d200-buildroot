################################################################################
#
# d200-deck: deckd, the D200 key app and update page
#
################################################################################

D200_DECK_VERSION = v0.1.1
D200_DECK_SITE = $(call github,riptidewave93,d200-deck,$(D200_DECK_VERSION))
D200_DECK_LICENSE = GPL-3.0+, Apache-2.0 (icons), MIT (GitHub mark), BSD-3-Clause (Go modules)
D200_DECK_LICENSE_FILES = LICENSE NOTICE.md
D200_DECK_GOMOD = github.com/riptidewave93/d200-deck
D200_DECK_BUILD_TARGETS = cmd/deckd
D200_DECK_LDFLAGS = -s -w -X main.version=$(D200_DECK_VERSION)
# Static: pure Go, no libc
D200_DECK_GO_ENV = CGO_ENABLED=0

define D200_DECK_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(D200_DECK_PKGDIR)/S60deckd $(TARGET_DIR)/etc/init.d/S60deckd
endef

$(eval $(golang-package))

# Download Go modules through the module proxy instead of from each module's
# own server; go.sum still checks them, and the build stays offline
D200_DECK_DL_ENV += GOPROXY=https://proxy.golang.org,direct
