mkdir -p $PREFIX/bin
cat > $PREFIX/bin/vps << 'EOF'
#!/usr/bin/env bash

CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"; touch "$CONFIG"; chmod 600 "$CONFIG"

# --- Colors ---
C_CYAN='\033[0;36m'; C_GREEN='\033[0;32m'; C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'; C_GRAY='\033[1;30m'; C_NC='\033[0m'; C_BOLD='\033[1m'

# --- Helpers ---
get_info() {
  local alias=$1
  local user=$(awk -v h="$alias" '$1=="Host" && $2==h {f=1} f && $1=="User" {print $2; exit}' "$CONFIG")
  local host=$(awk -v h="$alias" '$1=="Host" && $2==h {f=1} f && $1=="HostName" {print $2; exit}' "$CONFIG")
  local port=$(awk -v h="$alias" '$1=="Host" && $2==h {f=1} f && $1=="Port" {print $2; exit}' "$CONFIG")
  echo "${user:-root}@${host}${port:+:$port}"
}

add_vps() {
  echo -e "\n${C_YELLOW}Paste the ADD line from your VPS (or type 'cancel'):${C_NC}"
  echo -n "> "; read line
  [ "$line" = "cancel" ] && return
  if [[ "$line" != ADD:* ]]; then echo -e "${C_RED}Invalid format. Must start with ADD:${C_NC}"; sleep 2; return; fi
  
  IFS='|' read -r name ip user port <<< "${line#ADD:}"
  
  awk -v n="$name" '$1 == "Host" { in_block = ($2 == n) } !in_block { print }' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  
  echo -e "\nHost $name\n    HostName $ip\n    User ${user:-root}\n    Port ${port:-22}\n    StrictHostKeyChecking accept-new\n    RequestTTY yes\n    RemoteCommand tmux new -A -s main" >> "$CONFIG"
  
  echo -e "${C_GREEN}✓ Added $name${C_NC}"; sleep 1.5
}

del_vps() {
  local target=$1
  [ -z "$target" ] && { echo -n "Enter number or name to delete: "; read target; }
  if [[ "$target" =~ ^[0-9]+$ ]]; then target=$(echo "$HOSTS" | sed -n "${target}p"); fi
  if [ -z "$target" ] || ! grep -q "^Host $target$" "$CONFIG"; then echo -e "${C_RED}Not found.${C_NC}"; sleep 1.5; return; fi
  
  echo -n -e "${C_RED}Delete $target? [y/N]: ${C_NC}"; read confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    cp "$CONFIG" "$CONFIG.bak"
    awk -v n="$target" '$1 == "Host" { in_block = ($2 == n) } !in_block { print }' "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"; chmod 600 "$CONFIG"
    echo -e "${C_GREEN}✓ Deleted $target${C_NC}"
  fi
  sleep 1.5
}

test_vps() {
  local target=$1
  [ -z "$target" ] && { echo -n "Enter number or name to test: "; read target; }
  if [[ "$target" =~ ^[0-9]+$ ]]; then target=$(echo "$HOSTS" | sed -n "${target}p"); fi
  if [ -z "$target" ]; then return; fi
  
  echo -e "\n${C_CYAN}Testing $target...${C_NC}"
  if ssh -o ConnectTimeout=5 -o BatchMode=yes -o RemoteCommand=none "$target" "echo 'Connection OK'" 2>/dev/null; then
    echo -e "${C_GREEN}✓ Success! Server is reachable and key is authorized.${C_NC}"
  else
    echo -e "${C_RED}✗ Failed to connect.${C_NC}"
    echo -e "${C_GRAY}Possible reasons: Server is off, wrong port, or key is missing.${C_NC}"
  fi
  echo -e "\nPress Enter to return..."; read
}

connect_vps() {
  local target=$1
  local def_user=$(awk -v h="$target" '$1=="Host" && $2==h {f=1} f && $1=="User" {print $2; exit}' "$CONFIG")
  def_user=${def_user:-root}

  clear
  echo -e "${C_CYAN}${C_BOLD}Connect to $target${C_NC}"
  echo -e "  ${C_GREEN}1)${C_NC} Login as ${C_BOLD}$def_user${C_NC} (default)"
  echo -e "  ${C_GREEN}2)${C_NC} Login as ${C_BOLD}abc${C_NC}"
  echo -e "  ${C_GREEN}3)${C_NC} Login as ${C_BOLD}custom user${C_NC}"
  echo -e "  ${C_GRAY}Press Enter to cancel${C_NC}"
  echo -n -e "  ${C_CYAN}Select [1]: ${C_NC}"; read u_choice

  local final_user=$def_user
  case "$u_choice" in
    ""|1) final_user=$def_user ;;
    2) final_user="abc" ;;
    3) echo -n "  Enter username: "; read final_user ;;
    *) return ;; 
  esac

  echo -e "\n${C_CYAN}→ Connecting to $target as $final_user...${C_NC}"
  
  # Acquire Termux wake lock so Android doesn't kill the Wi-Fi
  command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1
  
  sleep 0.5
  # Use a unique tmux session for each user to prevent collisions
  ssh -l "$final_user" -o RemoteCommand=none -t "$target" "tmux new -A -s main_$final_user || bash"
  
  echo -e "\n${C_GRAY}Connection closed.${C_NC}"
  
  # Release wake lock
  command -v termux-wake-unlock >/dev/null 2>&1 && termux-wake-unlock >/dev/null 2>&1
  
  echo -e "Press Enter to return..."; read
}

menu() {
  while true; do
    clear
    echo -e "${C_CYAN}${C_BOLD}╔══════════════════════════════════════════╗${C_NC}"
    echo -e "${C_CYAN}${C_BOLD}║            ☁️  MY CLOUD SERVERS           ║${C_NC}"
    echo -e "${C_CYAN}${C_BOLD}╚══════════════════════════════════════════╝${C_NC}"
    
    HOSTS=$(grep -E "^Host " "$CONFIG" | awk '{print $2}')
    
    if [ -z "$HOSTS" ]; then
      echo -e "  ${C_YELLOW}No VPS configured yet. Press 'a' to add one.${C_NC}"
    else
      i=1
      for h in $HOSTS; do
        info=$(get_info "$h")
        printf "  ${C_GREEN}%2d)${C_NC} ${C_BOLD}%-15s${C_NC} ${C_GRAY}%s${C_NC}\n" "$i" "$h" "$info"
        i=$((i+1))
      done
    fi
    
    echo -e "\n  ${C_YELLOW}a)${C_NC} Add VPS      ${C_YELLOW}d)${C_NC} Delete VPS"
    echo -e "  ${C_YELLOW}t)${C_NC} Test VPS     ${C_YELLOW}e)${C_NC} Edit Config"
    echo -e "  ${C_YELLOW}q)${C_NC} Quit\n"
    
    echo -n -e "  ${C_CYAN}Select an option or number: ${C_NC}"; read choice
    
    case "$choice" in
      q|Q) clear; exit 0 ;;
      a|A) add_vps ;;
      d|D) del_vps "" ;;
      t|T) test_vps "" ;;
      e|E) nano "$CONFIG" ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          target=$(echo "$HOSTS" | sed -n "${choice}p")
          [ -n "$target" ] && connect_vps "$target"
        fi
        ;;
    esac
  done
}

# Quick Connect (vps 1 or vps name)
if [ $# -gt 0 ]; then
  HOSTS=$(grep -E "^Host " "$CONFIG" | awk '{print $2}')
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    target=$(echo "$HOSTS" | sed -n "${1}p")
    [ -n "$target" ] && connect_vps "$target" && exit 0
  else
    if echo "$HOSTS" | grep -qx "$1"; then
      connect_vps "$1" && exit 0
    fi
  fi
fi

menu
EOF
chmod +x $PREFIX/bin/vps
