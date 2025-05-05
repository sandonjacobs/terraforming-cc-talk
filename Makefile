.PHONY: cc-base-init cc-base-plan cc-base-apply cc-base-deploy cc-conn-init cc-conn-plan cc-conn-apply cc-conn-deploy help

# Help documentation
help:
	@echo "Available targets:"
	@echo "  cc-base-init    - Initialize Terraform in cc-terraform-base directory"
	@echo "  cc-base-plan    - Show Terraform execution plan for cc-terraform-base"
	@echo "  cc-base-apply   - Apply Terraform configuration for cc-terraform-base"
	@echo "  cc-base-deploy  - Run init, plan, and apply for cc-terraform-base"
	@echo ""
	@echo "  cc-conn-init    - Initialize Terraform in cc-connectors directory"
	@echo "  cc-conn-plan    - Show Terraform execution plan for cc-connectors"
	@echo "  cc-conn-apply   - Apply Terraform configuration for cc-connectors"
	@echo "  cc-conn-deploy  - Run init, plan, and apply for cc-connectors"
	@echo ""
	@echo "  help           - Show this help message"

cc-base-init:
	cd cc-terraform-base && terraform init

cc-base-plan:
	cd cc-terraform-base && terraform plan

cc-base-apply:
	cd cc-terraform-base && terraform apply -auto-approve

cc-base-deploy: cc-base-init cc-base-plan cc-base-apply

cc-conn-init:
	cd cc-connectors && terraform init

cc-conn-plan:
	cd cc-connectors && terraform plan

cc-conn-apply:
	cd cc-connectors && terraform apply -auto-approve

cc-conn-deploy: cc-conn-init cc-conn-plan cc-conn-apply 