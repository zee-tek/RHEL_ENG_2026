#!/bin/bash

# ===== COLORS =====
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
YELLOW="\e[33m"
NC="\e[0m"

pass() { echo -e "${GREEN}✔ $1${NC}"; }
fail() { echo -e "${RED}✖ $1${NC}"; }
info() { echo -e "${YELLOW}➜ $1${NC}"; }
header() { echo -e "\n${BLUE}==== $1 ====${NC}"; }

BASE_DIR="/home/student/ansible"
INVENTORY="$BASE_DIR/inventory"

cd "$BASE_DIR" || exit 1

# ===== AUTO RESET =====
auto_reset() {
header "RESETTING ENVIRONMENT"

ansible all -i "$INVENTORY" -m file -a "path=/web state=absent" >/dev/null
ansible all -i "$INVENTORY" -m file -a "path=/etc/yum.repos.d/baseos.repo state=absent" >/dev/null
ansible all -i "$INVENTORY" -m file -a "path=/etc/yum.repos.d/appstream.repo state=absent" >/dev/null

ansible all -i "$INVENTORY" -m yum -a "name=wget state=absent" >/dev/null
ansible dev -i "$INVENTORY" -m yum -a "name=httpd state=absent" >/dev/null
ansible test -i "$INVENTORY" -m yum -a "name='@RPM Development Tools' state=absent" >/dev/null

ansible dev -i "$INVENTORY" -m cron -a "name='ansi_user job' user=ansi_user state=absent" >/dev/null
ansible dev -i "$INVENTORY" -m file -a "path=/var/www/html/web state=absent" >/dev/null

pass "Environment reset complete"
}

# ===== RESULT =====
result_badge() {
    echo -e "\nScore: $score / $total"
    if [ "$score" -eq "$total" ]; then
        echo -e "${GREEN}🎉 FINAL RESULT: PASS ✅${NC}"
    else
        echo -e "${RED}❌ FINAL RESULT: FAIL ❌${NC}"
    fi
}

# ===== RUN PLAYBOOK =====
run_playbook() {
    PB="$1"

    auto_reset
    info "Executing playbook..."

    ansible-playbook -i "$INVENTORY" "$PB" >/dev/null
    if [ $? -ne 0 ]; then
        fail "Playbook execution FAILED"
        return 1
    fi

    pass "Playbook executed successfully ($PB)"
    return 0
}

# ===== MENU =====
echo -e "${BLUE}========== ANSIBLE LAB EVALUATION ==========${NC}"
echo "1) lab-1-Q"
echo "2) lab-2-Q"
echo "3) lab-3-Q"
echo "4) lab-4-Q"
echo "5) Exit"

read -p "Enter choice [1-5]: " choice

# =========================
# LAB 1
# =========================
lab1() {
header "LAB-1-Q"

score=0
total=3

EXPECTED="install-pkgs.yml"
PB="$BASE_DIR/$EXPECTED"

if [ -f "$PB" ]; then
    pass "Playbook exists ($EXPECTED)"
    ((score++))
else
    fail "Missing playbook"
    info "Expected playbook: $EXPECTED"
    return
fi

run_playbook "$PB" || return

ansible dev -m shell -a "rpm -q wget" | grep -vq "not installed" \
&& pass "wget installed" && ((score++)) || fail "wget missing"

ansible test -m shell -a "yum grouplist installed" | grep -q "RPM Development Tools" \
&& pass "RPM Dev Tools installed" && ((score++)) || fail "RPM Dev Tools missing"

result_badge
}

# =========================
# LAB 2
# =========================
lab2() {
header "LAB-2-Q"

score=0
total=3

EXPECTED="yumrepo.yaml"
PB="$BASE_DIR/$EXPECTED"

if [ -f "$PB" ]; then
    pass "Playbook exists ($EXPECTED)"
    ((score++))
else
    fail "Missing playbook"
    info "Expected playbook: $EXPECTED"
    return
fi

run_playbook "$PB" || return

ansible all -m shell -a "yum repolist enabled | grep -i baseos" | grep -q rc=0 \
&& pass "baseos repo enabled" && ((score++)) || fail "baseos not enabled"

ansible all -m shell -a "yum repolist enabled | grep -i appstream" | grep -q rc=0 \
&& pass "appstream repo enabled" && ((score++)) || fail "appstream not enabled"

result_badge
}

# =========================
# LAB 3
# =========================
lab3() {
header "LAB-3-Q"

score=0
total=3

EXPECTED="cron.yml"
PB="$BASE_DIR/$EXPECTED"

if [ -f "$PB" ]; then
    pass "Playbook exists ($EXPECTED)"
    ((score++))
else
    fail "Missing playbook"
    info "Expected playbook: $EXPECTED"
    return
fi

run_playbook "$PB" || return

cron_line=$(ansible dev -m shell -a "crontab -l -u ansi_user" | grep logger)

[ -n "$cron_line" ] && pass "cron exists" && ((score++)) || fail "cron missing"

echo "$cron_line" | grep -q "*/2" \
&& pass "schedule correct" && ((score++)) || fail "schedule incorrect"

result_badge
}

# =========================
# LAB 4
# =========================
lab4() {
header "LAB-4-Q"

score=0
total=8

EXPECTED="content.yml"
PB="$BASE_DIR/$EXPECTED"

if [ -f "$PB" ]; then
    pass "Playbook exists ($EXPECTED)"
    ((score++))
else
    fail "Missing playbook"
    info "Expected playbook: $EXPECTED"
    return
fi

run_playbook "$PB" || return

ansible dev -m shell -a "rpm -q httpd" | grep -vq "not installed" \
&& pass "httpd installed" && ((score++)) || fail "httpd not installed"

ansible dev -m stat -a "path=/web" | grep -q '"isdir": true' \
&& pass "/web exists" && ((score++)) || fail "/web missing"

ansible dev -m shell -a "stat -c %G /web" | grep -q ansi_user \
&& pass "group correct" && ((score++)) || fail "group incorrect"

ansible dev -m shell -a "stat -c %a /web" | grep -q 2775 \
&& pass "permissions correct" && ((score++)) || fail "permissions incorrect"

ansible dev -m shell -a "ls -Zd /web" | grep -q httpd_sys_content_t \
&& pass "SELinux correct" && ((score++)) || fail "SELinux incorrect"

ansible dev -m shell -a "cat /web/index.html" | grep -q "Learning Ansible" \
&& pass "content correct" && ((score++)) || fail "content incorrect"

ansible dev -m stat -a "path=/var/www/html/web" | grep -q '"islnk": true' \
&& pass "symlink correct" && ((score++)) || fail "symlink incorrect"

result_badge
}

# ===== ROUTER =====
case $choice in
    1) lab1 ;;
    2) lab2 ;;
    3) lab3 ;;
    4) lab4 ;;
    5) exit 0 ;;
    *) fail "Invalid choice" ;;
esac

echo -e "\n${BLUE}========== EVALUATION DONE ==========${NC}"
