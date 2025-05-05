.PHONY: cc-base-init cc-base-plan cc-base-apply cc-base-deploy

cc-base-init:
	cd cc-terraform-base && terraform init

cc-base-plan:
	cd cc-terraform-base && terraform plan

cc-base-apply:
	cd cc-terraform-base && terraform apply -auto-approve

cc-base-deploy: cc-base-init cc-base-plan cc-base-apply 