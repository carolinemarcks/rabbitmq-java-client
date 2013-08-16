VERSION=0.0.0
PACKAGE_NAME=rabbitmq-java-client
JAVADOC_ARCHIVE=$(PACKAGE_NAME)-javadoc-$(VERSION)
SRC_ARCHIVE=$(PACKAGE_NAME)-$(VERSION)
SIGNING_KEY=056E8E56
GNUPG_PATH=~
M2_ENCRYPTED_HOME=$(GNUPG_PATH)/../nexus/

WEB_URL=http://www.rabbitmq.com/
NEXUS_STAGE_URL=http://oss.sonatype.org/service/local/staging/deploy/maven2
MAVEN_NEXUS_VERSION=1.7

AMQP_CODEGEN_DIR=$(shell fgrep sibling.codegen.dir build.properties | sed -e 's:sibling\.codegen\.dir=::')

MAVEN_RSYNC_DESTINATION=maven@195.224.125.254:/home/maven/rabbitmq-java-client/

all:
	ant build

clean:
	ant clean

distclean: clean
	make -C $(AMQP_CODEGEN_DIR) clean

dist: distclean srcdist dist_all maven-bundle

dist_all: dist1.5 javadoc-archive

maven-bundle:
	ant -Dimpl.version=$(VERSION) maven-bundle

dist1.5:
	ant -Ddist.out=build/$(PACKAGE_NAME)-bin-$(VERSION) -Dimpl.version=$(VERSION) dist
	$(MAKE) post-dist TARBALL_NAME=$(PACKAGE_NAME)-bin-$(VERSION)

javadoc-archive:
	ant javadoc
	cp -Rp build/doc/api build/$(JAVADOC_ARCHIVE)
	(cd build; tar -zcf $(JAVADOC_ARCHIVE).tar.gz $(JAVADOC_ARCHIVE))
	(cd build; zip -q -r $(JAVADOC_ARCHIVE).zip $(JAVADOC_ARCHIVE))
	(cd build; rm -rf $(JAVADOC_ARCHIVE))

post-dist:
	@[ -n "$(TARBALL_NAME)" ] || (echo "Please set TARBALL_NAME."; false)
	chmod a+x build/$(TARBALL_NAME)/*.sh
	cp LICENSE* build/$(TARBALL_NAME)
	(cd build; tar -zcf $(TARBALL_NAME).tar.gz $(TARBALL_NAME))
	(cd build; zip -q -r $(TARBALL_NAME).zip $(TARBALL_NAME))
	(cd build; rm -rf $(TARBALL_NAME))

srcdist: distclean
	mkdir -p build/$(SRC_ARCHIVE)
	cp -Rp `ls | grep -v '^\(build\|README.in\)$$'` build/$(SRC_ARCHIVE)

	mkdir -p build/$(SRC_ARCHIVE)/codegen
	cp -r $(AMQP_CODEGEN_DIR)/* build/$(SRC_ARCHIVE)/codegen/.

	if [ -f README.in ]; then \
		cp README.in build/$(SRC_ARCHIVE)/README; \
		elinks -dump -no-references -no-numbering $(WEB_URL)build-java-client.html \
			>> build/$(SRC_ARCHIVE)/README; \
	fi
	(cd build; tar -zcf $(SRC_ARCHIVE).tar.gz $(SRC_ARCHIVE))
	(cd build; zip -q -r $(SRC_ARCHIVE).zip $(SRC_ARCHIVE))
	(cd build; rm -rf $(SRC_ARCHIVE))

# nexus username and password must come from the encrypted $M2_HOME/settings.xml
stage-and-promote-maven-bundle:
	( \
	  cd build/bundle; \
	  M2_HOME="$(M2_ENCRYPTED_HOME)/settings.xml"
	  mvn gpg:sign-and-deploy-file \
		-Durl=$(NEXUS_BASE_URI)/nexus/content/repositories/releases \
		-DrepositoryId=sonatype-nexus-staging \
	    	-DpomFile=amqp-client-$(VERSION).pom \
		-Dfile=amqp-client-$(VERSION).jar \
		-Dsources=amqp-client-$(VERSION)-sources.jar \
		-Djavadoc=amqp-client-$(VERSION)-javadoc.jar \
		-Dhomedir=$(GNUPG_PATH) \
	)

