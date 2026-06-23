#!/bin/bash

# ===== VARIABLES =====
BASE_DIR="/home/student/ansible"
INVENTORY="$BASE_DIR/inventory"
ANSIBLE_CFG="$BASE_DIR/ansible.cfg"
COLLECTIONS_DIR="$BASE_DIR/collections"

echo "========== CLEANUP SCRIPT =========="

# ===== MANAGED NODES TASKS =====
echo "Running cleanup on managed nodes..."

ansible all -i "$INVENTORY" -m file -a "path=/web state=absent"

ansible all -i "$INVENTORY" -m file -a "path=/etc/yum.repos.d/baseos.repo state=absent"
ansible all -i "$INVENTORY" -m file -a "path=/etc/yum.repos.d/appstream.repo state=absent"

ansible all -i "$INVENTORY" -m package -a "name=wget state=absent"

echo "Managed nodes cleanup done."

# ===== CONTROLLER NODE TASKS =====
echo
echo "Controller node cleanup options:"

# ---- Inventory ----
read -p "Do you want to delete the inventory file? (y/n): " inv_choice
if [[ $inv_choice == "y" ]]; then
    rm -f "$INVENTORY"
    echo "Inventory file deleted."
else
    echo "Skipped deleting inventory."
fi

# ---- ansible.cfg ----
read -p "Do you want to delete ansible.cfg? (y/n): " cfg_choice
if [[ $cfg_choice == "y" ]]; then
    rm -f "$ANSIBLE_CFG"
    echo "ansible.cfg deleted."
else
    echo "Skipped deleting ansible.cfg."
fi

# ---- collections ----
read -p "Do you want to delete Ansible collections at $COLLECTIONS_DIR? (y/n): " coll_choice
if [[ $coll_choice == "y" ]]; then
    if [ -d "$COLLECTIONS_DIR" ]; then
        rm -rf "${COLLECTIONS_DIR:?}/"*
        echo "Collections deleted."
    else
        echo "Collections directory not found."
    fi
else
    echo "Skipped deleting collections."
fi

echo
echo "========== CLEANUP COMPLETED =========="
