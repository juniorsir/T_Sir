#!/data/data/com.termux/files/usr/bin/bash
set -e
# ===== Colors (safe) =====
if [ -t 1 ]; then
  RED='\e[1;31m'
  GREEN='\e[1;32m'
  YELLOW='\e[1;33m'
  BLUE='\e[1;34m'
  CYAN='\e[1;36m'
  DIM='\e[2m'
  RESET='\e[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; DIM=''; RESET=''
fi

log()   { echo -e "${CYAN}[*]${RESET} $1"; }
ok()    { echo -e "${GREEN}[✔]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $1"; }
error() { echo -e "${RED}[✘]${RESET} $1"; }
### ========= USERNAME =========
log "Creating new environment"
read -p "Enter your username: " username
[ -z "$username" ] && { error "Username cannot be empty"; exit 1; }
ok "Username set: $username"

USER_HOME="$HOME/users/$username"
PASS_FILE="$HOME/.${username}_pass"
LOGIN_SCRIPT="$HOME/login-$username.sh"

log "Preparing private home directory"
mkdir -p "$USER_HOME"
ok "Directory created at $USER_HOME"

### ========= CREATE PRIVATE .bashrc =========
cat > "$USER_HOME/.bashrc" <<'EOF'
# Clear screen and show fake hacking intro
clear

typewriter() {
  local text="$1"
  for ((i=0; i<${#text}; i++)); do
    echo -n "${text:$i:1}"
    sleep 0.03
  done
  echo
}

loading_animation() {
  local msg="$1"
  echo -ne "\e[0;32m$msg"
  for i in {1..3}; do
    echo -n "."
    sleep 0.3
  done
  echo -e "\e[0m"
}

clear
typewriter "[+] Access Granted - Welcome, sir"
for i in {1..5}; do
  loading_animation "[~] Initializing Module $i"
done

# Optional ASCII Art (figlet, etc.)
echo -e "\e[1;30m"
echo -e "\e[0m"

# Show last 5 commands in dim style
echo -e "\e[2mPrevious commands:\e[0m"
history | tail -n 5 | sed 's/^/  \x1b[2m/' | sed 's/$/\x1b[0m/'

# Aliases
alias ls='ls --color=auto -F'
alias ll='ls -la --color=auto -F'
alias rm='mv --target-directory=$HOME/.trash'
alias dusage='du -sh * | sort -h'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# System status
get_battery() {
  command -v termux-battery-status >/dev/null &&
  termux-battery-status | jq -r '.percentage' 2>/dev/null
}

show_exit_code() {
  local code=$?
  [ $code -ne 0 ] && echo -e " \e[1;31m✘ $code\e[0m"
}

quotes=(
  "Trust no one."
  "Access granted."
  "Stay frosty."
  "Welcome to the matrix."
  "Code is poetry."
)

if [ "${#quotes[@]}" -gt 0 ]; then
  idx=$((RANDOM % ${#quotes[@]}))
  echo -e "\n\e[1;32m[+] ${quotes[$idx]}\e[0m\n"
fi

# 🔥 ORIGINAL PROMPT COLORS (UNCHANGED)
export PS1='\
\e[90m╭─[\e[36m⏱ \t\e[90m]──[\e[1;35msir\e[90m]──[\e[33m⚡$(get_battery)%\e[90m]\n\
╰─[\e[1;34m\w\e[90m]$(show_exit_code)\e[0m\n\
\e[1;32m➜ \e[0m'

cd ~

run_custom_shell() {
  while true; do
    read -e -r -p $'\n\e[1;32m➜ \e[0m' cmd
    [[ -z "$cmd" ]] && continue

    if [[ "$cmd" == "exit" ]]; then
      echo -e "\n\e[1;32m[+] Session Ended\e[0m"
      break
    fi

    if [[ "$cmd" =~ ^(nano|vi|vim|bash|less|more|man|top|clear|reset|history|tail).* ]]; then
      eval "$cmd"
      continue
    fi

    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n\e[1;34m[$timestamp] \$ \e[0;36m$cmd\e[0m"
    echo -e "\e[1;34m┌─[ Executing: \e[0;36m$cmd\e[1;34m ]\e[0m"

    start=$(date +%s%3N)

    if [[ "$cmd" == "cd" || "$cmd" == cd\ * ]]; then
      eval "$cmd"
      code=$?

      if [[ "$PWD" == "$HOME" ]]; then
        output="home"
      else
        output="${PWD/#$HOME/~}"
      fi
    else
      output=$(eval "$cmd" 2>&1)
      code=$?
    fi

    i=0
    while IFS= read -r line; do
      (( i++ % 2 == 0 )) \
        && echo -e "\e[0;37m│ $line\e[0m" \
        || echo -e "\e[0;90m│ $line\e[0m"
    done <<< "$output"

    end=$(date +%s%3N)
    duration=$(awk "BEGIN {printf \"%.2f\", ($end - $start)/1000}")

    if [[ $code -eq 0 ]]; then
      echo -e "\e[1;34m└─[\e[1;32m✔ Done\e[1;34m ⏱ ${duration}s]\e[0m"
    else
      echo -e "\e[1;34m└─[\e[1;31m✘ Exit Code: $code\e[1;34m ⏱ ${duration}s]\e[0m"
    fi
  done
}

[[ $- == *i* ]] && run_custom_shell

cd "$HOME"
EOF

### ========= PASSWORD SET =========
log "Setting password for $username"
read -sp "Password: " pass
echo
[ -z "$pass" ] && { error "Password cannot be empty"; exit 1; }
ok "Password set"

echo -n "$pass" | sha256sum | awk '{print $1}' > "$PASS_FILE"
chmod 600 "$PASS_FILE"
unset pass

### ========= CREATE LOGIN SCRIPT =========
cat > "$LOGIN_SCRIPT" <<EOF
#!/data/data/com.termux/files/usr/bin/bash

PASS_FILE="$PASS_FILE"
USER_HOME="$USER_HOME"

if command -v termux-dialog >/dev/null; then
  pass_input=\$(termux-dialog -p -t "Login: $username" | jq -r '.text')
else
  echo -n "Password: "
  read -s pass_input
  echo
fi

[ -z "\$pass_input" ] || [ "\$pass_input" = "null" ] && {
  echo "Login cancelled."
  exit 1
}

input_hash=\$(echo -n "\$pass_input" | sha256sum | awk '{print \$1}')
stored_hash=\$(cat "\$PASS_FILE" 2>/dev/null)

if [ "\$input_hash" != "\$stored_hash" ]; then
  command -v termux-toast >/dev/null && termux-toast "Access denied"
  echo "Access denied"
  exit 1
fi

command -v termux-toast >/dev/null && termux-toast "Welcome $username"

env HOME="\$USER_HOME" bash --rcfile "\$USER_HOME/.bashrc"
EOF

log "Installing login command"
mv "$LOGIN_SCRIPT" "$PATH/$username"
chmod +x "$PATH/$username"
ok "Command '$username' installed"
### ========= DONE =========
echo
echo
echo -e "${GREEN}====================================${RESET}"
echo -e "${GREEN}  ✔ Environment created successfully${RESET}"
echo -e "${GREEN}  ▶ Start by typing: ${YELLOW}$username${RESET}"
echo -e "${GREEN}====================================${RESET}"
