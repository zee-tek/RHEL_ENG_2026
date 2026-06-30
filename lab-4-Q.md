# Ansible Lab Task

Create an Ansible playbook named `content.yml` that runs on the `dev` group and performs the following tasks:

## Requirements

1. Install the `httpd` package.

2. Create a directory `/web`:
   - The directory should be owned by the group `ansi_user`.

3. Set the SELinux context type of `/web` to `httpd`.

4. Assign permissions to `/web`:
   - User: `rwx`
   - Group: `rwx`
   - Others: `rx`
   - Ensure the **setgid (group special permission)** is applied.

5. Create a file named `index.html` under `/web` with the following content:
6. create a link of `/web` to `/var/www/html/web`
