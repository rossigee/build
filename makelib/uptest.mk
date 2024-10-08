# ====================================================================================
# End to End Testing

UPTEST_EXTRA_ARGS ?=

UPTEST_COMMAND = SKIP_DEPLOY_ARGO=$(SKIP_DEPLOY_ARGO) \
	KUBECTL=$(KUBECTL) \
	CHAINSAW=$(CHAINSAW) \
	CROSSPLANE_CLI=$(CROSSPLANE_CLI) \
	CROSSPLANE_NAMESPACE=$(CROSSPLANE_NAMESPACE) \
	YQ=$(YQ) \
	$(UPTEST) e2e $(UPTEST_CLAIMS) \
	--data-source="${UPTEST_DATASOURCE_PATH}" \
	--setup-script=$(UPTEST_SETUP_SCRIPT) \
	--default-timeout=2400s \
	--skip-update \
	--skip-import \
	$(UPTEST_EXTRA_ARGS)

# This target requires the following environment variables to be set:
# - To ensure the proper functioning of the end-to-end test resource pre-deletion hook, it is crucial to arrange your resources appropriately.
#   You can check the basic implementation here: https://github.com/upbound/uptest/blob/main/internal/templates/01-delete.yaml.tmpl.
# - UPTEST_DATASOURCE_PATH (optional), see https://github.com/upbound/uptest#injecting-dynamic-values-and-datasource
UPTEST_SETUP_SCRIPT ?= test/setup.sh
uptest: $(UPTEST) $(KUBECTL) $(CHAINSAW) $(CROSSPLANE_CLI) $(YQ)
	@$(INFO) running automated tests
	$(UPTEST_COMMAND) || $(FAIL)
	@$(OK) running automated tests

# Run uptest together with all dependencies. Use `make e2e UPTEST_EXTRA_ARGS=--skip-delete` to skip deletion of resources.
e2e: build controlplane.down controlplane.up local.xpkg.deploy.configuration.$(PROJECT_NAME) uptest #

render: $(CROSSPLANE_CLI) ${YQ}
	@indir="./examples"; \
	for file in $$(find $$indir -type f -name '*.yaml' ); do \
	    doc_count=$$(grep -c '^---' "$$file"); \
	    if [[ $$doc_count -gt 0 ]]; then \
	        continue; \
	    fi; \
	    COMPOSITION=$$(${YQ} eval '.metadata.annotations."render.crossplane.io/composition-path"' $$file); \
	    FUNCTION=$$(${YQ} eval '.metadata.annotations."render.crossplane.io/function-path"' $$file); \
	    ENVIRONMENT=$$(${YQ} eval '.metadata.annotations."render.crossplane.io/environment-path"' $$file); \
	    OBSERVE=$$(${YQ} eval '.metadata.annotations."render.crossplane.io/observe-path"' $$file); \
	    if [[ "$$ENVIRONMENT" == "null" ]]; then \
	        ENVIRONMENT=""; \
	    fi; \
	    if [[ "$$OBSERVE" == "null" ]]; then \
	        OBSERVE=""; \
	    fi; \
	    if [[ "$$COMPOSITION" == "null" || "$$FUNCTION" == "null" ]]; then \
	        continue; \
	    fi; \
	    ENVIRONMENT=$${ENVIRONMENT=="null" ? "" : $$ENVIRONMENT}; \
	    OBSERVE=$${OBSERVE=="null" ? "" : $$OBSERVE}; \
	    $(CROSSPLANE_CLI) render $$file $$COMPOSITION $$FUNCTION $${ENVIRONMENT:+-e $$ENVIRONMENT} $${OBSERVE:+-o $$OBSERVE} -x; \
	done

YAMLLINT_FOLDER ?= ./apis
yamllint: ## Static yamllint check
	@$(INFO) running yamllint
	@yamllint $(YAMLLINT_FOLDER) || $(FAIL)
	@$(OK) running yamllint

.PHONY: uptest e2e render yamllint


