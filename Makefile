.PHONY: init apply outputs start

init:
	cd infra && terraform init

apply:
	cd infra && terraform apply -auto-approve

outputs:
	cd infra && terraform output -json > ../tf-outputs.json

start:
	@if [ ! -f tf-outputs.json ]; then \
		echo "Error: tf-outputs.json not found. Run 'make outputs' first."; \
		exit 1; \
	fi
	@jq -r .dms_task_arn.value tf-outputs.json | xargs -I{} bash -c 'DMS_TASK_ARN={} ./scripts/start_dms.sh'
