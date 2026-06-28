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
LOGFILE="/tmp/ansible_eval_$$.log"

cd "$BASE_DIR" || exit 1
: > "$LOGFILE"

# =====================================================================
# check() -- auto-increments total every time it's called, so totals
# can never drift out of sync with the number of checks actually run.
# Usage: check "description" <command> [args...]
#        The command must return 0 for pass, non-zero for fail.
# =====================================================================
check() {
    local desc="$1"; shift
    ((total++))
    if "$@"; then
        pass "$desc"; ((score++))
    else
        fail "$desc"
    fi
}

# =====================================================================
# host_check() -- runs a command against every host in a group with
# -o (one-line-per-host output) and requires ALL hosts to satisfy the
# condition. This fixes two bugs in the original script:
#   1. "grep -v -q pattern" against multi-line ansible output is almost
#      always true, because ansible's own header line never contains
#      the pattern -- it doesn't actually test what it looks like it
#      tests. Using -o collapses header+stdout onto a single line per
#      host, so a plain grep for/against the pattern is meaningful.
#   2. Checks against a group with more than one host used to pass if
#      ANY single host matched. This requires every targeted host to
#      match.
# mode: "contains" -> every host's output must contain pattern
#       "absent"   -> every host's output must NOT contain pattern
# =====================================================================
host_check() {
    local group="$1" cmd="$2" mode="$3" pattern="$4"
    local out
    out=$(ansible "$group" -i "$INVENTORY" -m shell -a "$cmd" -o 2>>"$LOGFILE")
    [ -z "$out" ] && return 1
    while IFS= read -r line; do
        if echo "$line" | grep -qE "UNREACHABLE!|FAILED!"; then
            return 1
        fi
        if [ "$mode" = "contains" ]; then
            echo "$line" | grep -qF -- "$pattern" || return 1
        else
            echo "$line" | grep -qF -- "$pattern" && return 1
        fi
    done <<< "$out"
    return 0
}

# Dedicated check for "all packages updated/patched" on prod -- relies
# on dnf check-update's exit code (0 = nothing pending, 100 = updates
# available) rather than text-matching, which is the correct way to
# test this.
prod_patched_check() {
    local out
    out=$(ansible prod -i "$INVENTORY" -m shell \
        -a "dnf check-update -q >/dev/null 2>&1; echo EXIT_CODE=\$?" -o 2>>"$LOGFILE")
    [ -z "$out" ] && return 1
    while IFS= read -r line; do
        echo "$line" | grep -qE "UNREACHABLE!|FAILED!" && return 1
        echo "$line" | grep -qF "EXIT_CODE=0" || return 1
    done <<< "$out"
    return 0
}

# Heuristic structural check for "use multiple plays" -- counts
# top-level "hosts:" keys in the playbook file. Not a substitute for
# reading the file, but catches the obvious single-play case.
multi_play_check() {
    local count
    count=$(grep -c '^[[:space:]]\{0,4\}hosts:' "$PB")
    [ "$count" -ge 2 ]
}

# ===== AUTO RESET =====
# Resets artifacts from all 4 labs every run so each evaluation starts
# from a clean slate. Harmless to run before a lab whose artifacts
# don't exist yet (file/yum/cron modules are idempotent on removal).
auto_reset() {
    header "RESETTING ENVIRONMENT"

    ansible all -i "$INVENTORY" -m file -a "path=/web state=absent" >>"$LOGFILE" 2>&1
    ansible all -i "$INVENTORY" -m file -a "path=/etc/yum.repos.d/baseos.repo state=absent" >>"$LOGFILE" 2>&1
    ansible all -i "$INVENTORY" -m file -a "path=/etc/yum.repos.d/appstream.repo state=absent" >>"$LOGFILE" 2>&1

    ansible all -i "$INVENTORY" -m yum -a "name=wget state=absent" >>"$LOGFILE" 2>&1
    ansible dev -i "$INVENTORY" -m yum -a "name=httpd state=absent" >>"$LOGFILE" 2>&1
    ansible test -i "$INVENTORY" -m yum -a "name='@RPM Development Tools' state=absent" >>"$LOGFILE" 2>&1

    ansible dev -i "$INVENTORY" -m cron -a "name='ansi_user job' user=ansi_user state=absent" >>"$LOGFILE" 2>&1
    ansible dev -i "$INVENTORY" -m file -a "path=/var/www/html/web state=absent" >>"$LOGFILE" 2>&1

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

    if ! ansible-playbook -i "$INVENTORY" "$PB" >"$LOGFILE" 2>&1; then
        fail "Playbook execution FAILED -- last 20 lines of output:"
        tail -20 "$LOGFILE"
        info "Full log: $LOGFILE"
        return 1
    fi

    pass "Playbook executed successfully ($PB)"
    return 0
}

# =========================
# LAB 1 -- install-pkgs.yml
# =========================
lab1() {
    header "LAB-1 -- Package Install / Patch"
    score=0; total=0

    EXPECTED="install-pkgs.yml"
    PB="$BASE_DIR/$EXPECTED"

    check "Playbook exists ($EXPECTED)" test -f "$PB"
    if [ "$score" -ne "$total" ]; then
        info "Expected playbook: $EXPECTED"
        return
    fi

    run_playbook "$PB" || return

    check "wget installed on dev" host_check dev "rpm -q wget" absent "not installed"
    check "RPM Development Tools group installed on test" \
        host_check test "yum grouplist installed 2>/dev/null" contains "RPM Development Tools"
    check "All packages updated/patched on prod" prod_patched_check
    check "Multiple plays used in $EXPECTED" multi_play_check

    result_badge
}

# =========================
# LAB 2 -- yumrepo.yaml
# =========================
lab2() {
    header "LAB-2 -- Yum Repository Configuration"
    score=0; total=0

    EXPECTED="yumrepo.yaml"
    PB="$BASE_DIR/$EXPECTED"

    check "Playbook exists ($EXPECTED)" test -f "$PB"
    if [ "$score" -ne "$total" ]; then
        info "Expected playbook: $EXPECTED"
        return
    fi

    run_playbook "$PB" || return

    check "baseos repo enabled on all hosts" \
        host_check all "yum repolist enabled 2>/dev/null" contains "baseos"
    check "appstream repo enabled on all hosts" \
        host_check all "yum repolist enabled 2>/dev/null" contains "appstream"
    check "GPG check enabled for baseos repo" \
        host_check all "grep -qE '^gpgcheck[[:space:]]*=[[:space:]]*1' /etc/yum.repos.d/baseos.repo && echo OK" contains "OK"
    check "GPG check enabled for appstream repo" \
        host_check all "grep -qE '^gpgcheck[[:space:]]*=[[:space:]]*1' /etc/yum.repos.d/appstream.repo && echo OK" contains "OK"

    result_badge
}

# =========================
# LAB 3 -- cron.yml
# =========================
lab3() {
    header "LAB-3 -- Cron Job"
    score=0; total=0

    EXPECTED="cron.yml"
    PB="$BASE_DIR/$EXPECTED"

    check "Playbook exists ($EXPECTED)" test -f "$PB"
    if [ "$score" -ne "$total" ]; then
        info "Expected playbook: $EXPECTED"
        return
    fi

    run_playbook "$PB" || return

    check "Cron job exists for ansi_user on dev" \
        host_check dev "crontab -l -u ansi_user 2>/dev/null" contains "logger"
    check "Schedule is every 2 minutes (*/2)" \
        host_check dev "crontab -l -u ansi_user 2>/dev/null | grep logger" contains "*/2"
    check "Job message is 'practicing ansible'" \
        host_check dev "crontab -l -u ansi_user 2>/dev/null | grep logger" contains "practicing ansible"

    result_badge
}

# =========================
# LAB 4 -- content.yml
# =========================
lab4() {
    header "LAB-4 -- Web Content & SELinux"
    score=0; total=0

    EXPECTED="content.yml"
    PB="$BASE_DIR/$EXPECTED"

    check "Playbook exists ($EXPECTED)" test -f "$PB"
    if [ "$score" -ne "$total" ]; then
        info "Expected playbook: $EXPECTED"
        return
    fi

    run_playbook "$PB" || return

    check "httpd installed on dev" host_check dev "rpm -q httpd" absent "not installed"
    check "/web exists as a directory" host_check dev "stat -c %F /web 2>/dev/null" contains "directory"
    check "/web group is ansi_user" host_check dev "stat -c %G /web 2>/dev/null" contains "ansi_user"
    check "/web permissions are 2775" host_check dev "stat -c %a /web 2>/dev/null" contains "2775"
    check "/web SELinux type is httpd_sys_content_t" host_check dev "ls -Zd /web 2>/dev/null" contains "httpd_sys_content_t"
    check "index.html content is 'Learning Ansible'" host_check dev "cat /web/index.html 2>/dev/null" contains "Learning Ansible"
    check "/var/www/html/web is a symlink" host_check dev "stat -c %F /var/www/html/web 2>/dev/null" contains "symbolic link"
    check "Symlink points to /web" host_check dev "readlink /var/www/html/web 2>/dev/null" contains "/web"

    result_badge
}

# =====================================================================
# MENU -- supports a single lab, a comma/space-separated list, or
# "all", in one invocation (no more re-running the script per lab).
# =====================================================================
declare -A LAB_FUNCS=( [1]=lab1 [2]=lab2 [3]=lab3 [4]=lab4 )
declare -A LAB_NAMES=(
    [1]="Lab1 - Package Install (install-pkgs.yml)"
    [2]="Lab2 - Yum Repository (yumrepo.yaml)"
    [3]="Lab3 - Cron Job (cron.yml)"
    [4]="Lab4 - Web Content & SELinux (content.yml)"
)

echo -e "${BLUE}========== ANSIBLE LAB EVALUATION ==========${NC}"
for i in 1 2 3 4; do
    echo "$i) ${LAB_NAMES[$i]}"
done
echo "all) Run all labs"
echo "q) Quit"
echo
read -p "Enter choice(s) [e.g. 1, 1,3, 2 4, or all]: " input

input="${input,,}"   # lowercase
if [[ "$input" =~ ^(q|quit|exit|0|5)$ ]]; then
    exit 0
fi

selected=()
if [[ "$input" == "all" ]]; then
    selected=(1 2 3 4)
else
    IFS=', ' read -ra raw <<< "$input"
    for tok in "${raw[@]}"; do
        [[ -z "$tok" ]] && continue
        if [[ "$tok" =~ ^[1-4]$ ]]; then
            selected+=("$tok")
        else
            fail "Ignoring invalid selection: '$tok'"
        fi
    done
fi

if [ "${#selected[@]}" -eq 0 ]; then
    fail "No valid lab selected. Exiting."
    exit 1
fi

declare -A RESULTS
grand_score=0
grand_total=0

for n in "${selected[@]}"; do
    "${LAB_FUNCS[$n]}"
    RESULTS[$n]="${score:-0}/${total:-0}"
    grand_score=$((grand_score + ${score:-0}))
    grand_total=$((grand_total + ${total:-0}))
done

if [ "${#selected[@]}" -gt 1 ]; then
    header "OVERALL SUMMARY"
    for n in "${selected[@]}"; do
        echo -e "  ${LAB_NAMES[$n]}: ${RESULTS[$n]}"
    done
    echo -e "\nGrand Total: $grand_score / $grand_total"
    if [ "$grand_score" -eq "$grand_total" ]; then
        echo -e "${GREEN}🎉 OVERALL RESULT: PASS ✅${NC}"
    else
        echo -e "${RED}❌ OVERALL RESULT: FAIL ❌${NC}"
    fi
fi

echo -e "\n${BLUE}========== EVALUATION DONE ==========${NC}"
info "Full run log: $LOGFILE"
