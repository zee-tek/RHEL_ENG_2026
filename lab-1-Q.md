# Ansible Lab Task – Install Packages Using Multiple Plays

Create an Ansible playbook named `install-pkgs.yml` using **multiple plays** to perform the following tasks:

## Requirements

1. On `dev` hosts:
   - Install the `wget` package.

2. On `test` hosts:
   - Install the **RPM Development Tools** group Software.

3. On `prod` hosts:
   - Update all installed packages (apply latest patches).

## Notes

- Ensure the playbook uses **multiple plays** (separate plays for each host group).
