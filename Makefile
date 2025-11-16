.PHONY: init plan apply outputs start destroy

init:
	cd infra && terraform init

plan:
	cd infra && terraform plan

apply:
	cd infra && terraform apply -auto-approve

outputs:
	cd infra && terraform output -json > ../tf-outputs.json

start:
	@if [ ! -f tf-outputs.json ]; then \
		echo "Error: tf-outputs.json not found. Run 'make outputs' first."; \
		exit 1; \
	fi
	@echo "Refreshing outputs to ensure we have the latest task ARN..."
	@cd infra && terraform output -json > ../tf-outputs.json
	@jq -r .dms_task_arn.value tf-outputs.json | xargs -I{} bash -c 'DMS_TASK_ARN={} ./scripts/start_dms.sh'

destroy:
	cd infra && terraform destroy -auto-approve
	@echo "Cleaning up generated files..."
	@rm -f tf-outputs.json
	@rm -f infra/*.zip
	@rm -rf infra/lambda-layer
	@echo "Cleanup complete."
