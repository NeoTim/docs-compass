GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
USER=$(shell whoami)
STAGING_URL="https://docs-mongodbcom-staging.corp.mongodb.com"
PRODUCTION_URL="https://docs.mongodb.com"
STAGING_BUCKET=docs-mongodb-org-staging
PRODUCTION_BUCKET=docs-compass-prod
PROJECT=compass

# Parse our published-branches configuration file to get the name of
# the current "stable" branch. This is weird and dumb, yes.
STABLE_BRANCH=`grep 'manual' build/docs-tools/data/${PROJECT}-published-branches.yaml | cut -d ':' -f 2 | grep -Eo '[0-9a-z.]+'`

.PHONY: help html publish-artifacts stage fake-deploy deploy deploy-search-index

help:
	@echo 'Targets'
	@echo '  help               - Show this help message'
	@echo '  html               - Build html files'
	@echo '  publish-artifacts  - Build artifacts to deploy.'
	@echo '  stage              - Host online for review'
	@echo '  fake-deploy        - Create a fake deployment in the staging bucket'
	@echo '  deploy             - Deploy to the production bucket'
	@echo ''
	@echo 'Variables'
	@echo '  ARGS         - Arguments to pass to mut-publish'


html:
	giza make html

## makes just the artifacts
publish:
	giza make publish

stage:
	mut-publish build/${GIT_BRANCH}/html ${STAGING_BUCKET} --prefix=${PROJECT} --stage ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${PROJECT}/${USER}/${GIT_BRANCH}/index.html"

fake-deploy: build/public/${GIT_BRANCH}
	mut-publish build/public/${GIT_BRANCH} ${STAGING_BUCKET} --prefix=${PROJECT} --deploy ${ARGS}
	@echo "Hosted at ${STAGING_URL}/${PROJECT}/index.html"

deploy:
	@echo "Doing a dry-run"
	mut-publish build/public ${PRODUCTION_BUCKET} --prefix=${PROJECT} --deploy  --verbose  --redirects build/public/.htaccess --dry-run ${ARGS}

	@echo ''
	read -p "Press any key to perform the preceding statements to ${PRODUCTION_BUCKET}."
	mut-publish build/public ${PRODUCTION_BUCKET} --prefix=${PROJECT} --deploy ${ARGS} --verbose  --redirects build/public/.htaccess

	@echo "Hosted at ${PRODUCTION_URL}/${PROJECT}/${GIT_BRANCH}/index.html"

	$(MAKE) deploy-search-index

deploy-search-index: ## Update the search index for this branch
	@echo "Building search index"
	if [ ${STABLE_BRANCH} = ${GIT_BRANCH} ]; then \
		mut-index upload build/public/${GIT_BRANCH} -o ${PROJECT}-${GIT_BRANCH}.json -u ${PRODUCTION_URL}/${PROJECT}/current -g -s; \
	else \
		mut-index upload build/public/${GIT_BRANCH} -o ${PROJECT}-${GIT_BRANCH}.json -u ${PRODUCTION_URL}/${PROJECT}/${GIT_BRANCH} -s; \
	fi
