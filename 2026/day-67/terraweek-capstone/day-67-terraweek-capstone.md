# Day 67 - TerraWeek Capstone: Multi-Environment Infrastructure with Workspaces and Modules

## Task 1: Learn Terraform Workspaces

**What does `terraform.workspace` return inside a config?**
It returns the string name of the currently selected workspace (e.g., `"default"`, `"dev"`, `"staging"`, or `"prod"`). This allows you to dynamically inject the workspace name into resources as variables, tags, or names.

**Where does each workspace store its state file?**
When using the default local backend, Terraform stores workspace state files in a directory called `terraform.tfstate.d`, with subdirectories for each workspace: `terraform.tfstate.d/<workspace_name>/terraform.tfstate`. For remote backends like S3, it typically stores them in a similar logical path like `env:/<workspace_name>/path/to/key`.

**How is this different from using separate directories per environment?**
Using separate directories for environments means you have redundant root modules and configurations, requiring you to navigate and maintain changes separately or use tools like Terragrunt. Workspaces allow you to use a single set of Terraform configuration files (the same directory) across multiple environments that just use different state files and potentially different variable definitions (`.tfvars`), enforcing consistency and avoiding code duplication.

## Task 6: Terraform Best Practices Guide

Here is a summary of best practices for working with Terraform at scale, based on the concepts learned during TerraWeek:

* **File Structure**: Always keep your configurations modular and readable. Use separate files for `providers.tf`, `variables.tf`, `outputs.tf`, `main.tf`, and `locals.tf`.
* **State Management**: Always use a remote backend (such as S3) for collaborative environments. Enable state locking (e.g., using DynamoDB) to prevent concurrent operations, and enable bucket versioning to recover from accidental state corruption or deletion.
* **Variables**: Never hardcode values. Use `.tfvars` files specific to each environment to pass in values securely. Use `validation` blocks to ensure variables stay within expected inputs.
* **Modules**: Keep modules highly focused on one specific concern or resource group. Always document and define `inputs` and `outputs`. When using public registry modules, pin their versions to maintain stability across runs.
* **Workspaces**: Use workspaces for logic isolation of identical infrastructure deployments across different environments (dev/stage/prod) and leverage `terraform.workspace` dynamically in configurations.
* **Security**: Add `.gitignore` to prevent committing `.terraform`, `*.tfstate`, and sensitive `.tfvars`. Encrypt state at rest (especially for remote backends), and restrict access to the backend storage using IAM.
* **Commands**: Always run `terraform plan` to verify the execution plan before `terraform apply`. Consistently format logic using `terraform fmt` and validate logic using `terraform validate` before code reviews.
* **Tagging**: Standardize tagging. Tag every resource with key metadata like `Project`, `Environment`, and `ManagedBy` (Terraform) so that billing and identification are easier.
* **Naming**: Adopt a standard, consistent naming convention pattern like `<project>-<environment>-<resource_type>`.
* **Cleanup**: To save costs, routinely use `terraform destroy` for non-production environments when they are no longer in use.
