# Ansible Lab Task – Cron Job

Create an Ansible playbook named `cron.yml` that runs on the `dev` group and configures a cron job for the user `ansi_user`.

## Requirements

1. Create a cron job for the user `ansi_user`.

2. The cron job should execute the following command every 2 minutes:
   ```bash
   logger "practicing ansible"
