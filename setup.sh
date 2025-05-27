# Ask for username
read -p "Enter your username: " username
[ -z "$username" ] && {
  echo "Username cannot be empty."
  exit 1
}

# Create personal environment
mkdir -p ~/users/"$username"
cat > ~/users/"$username"/.bashrc <<EOF
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

# Function: Loading animation
loading_animation() {
  local msg="$1"
  echo -ne "\e[0;32m$msg"
  for i in {1..3}; do
    echo -n "."
    sleep 0.3
  done
  echo -e "\e[0m"
}
# Clear screen and show animated intro
clear
typewriter "[+] Access Granted - Welcome, JuniorSir"
for i in {1..5}; do
  loading_animation "[~] Initializing Module $i"
done

# Optional ASCII Art (figlet, etc.)
echo -e "\e[1;30m"
# figlet "JuniorSir" | lolcat
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

# File watcher
watch_file() {
  while inotifywait -e close_write "$1"; do
    bash "$1"
  done
}

# System status and git info
get_battery() { termux-battery-status | jq -r '.percentage' 2>/dev/null; }
show_exit_code() {
  local code=$?
  [ $code -ne 0 ] && echo -e " \e[1;31m✘ $code\e[0m"
}
quotes=(
  "Trust no one." "Access granted." "Stay frosty."
  "Welcome to the matrix." "Code is poetry."
  "Injecting some chaos." "Pwned by $username."
)
if [[ $- == *i* ]]; then
  echo -e "\n\e[1;32m[+] ${quotes[RANDOM % ${#quotes[@]}]}\e[0m\n"
fi

# Custom prompt
export PS1='\
\e[90m╭─[\e[36m⏱ \t\e[90m]──[\e[1;35m$username\e[90m]──[\e[33m⚡$(get_battery)%\e[90m]\n\
╰─[\e[1;34m\w\e[90m]$(show_exit_code)\e[0m\n\
\e[1;32m➜ \e[0m'

# Start in home directory
cd ~

# Disable auto-execution by Bash (use custom prompt loop instead)
run_custom_shell() {
  while true; do
    # Show your custom prompt
    echo -ne "\n\e[1;32m→ \e[0m"
    read -e -r cmd  # -e enables arrow key history, -r keeps literal input

    [[ -z "$cmd" ]] && continue

    # Handle exit manually
    if [[ "$cmd" == "exit" ]]; then
      echo -e "\n\e[1;32m[+] Session Ended\e[0m"
      break
    fi

    # Skip certain commands from being wrapped
    if [[ "$cmd" =~ ^(nano|vi|vim|bash|less|more|man|top|clear|reset|history|tail).* ]]; then
      eval "$cmd"
      continue
    fi

    # Show with timestamp and color
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n\e[1;34m[$timestamp] \$ \e[0;36m$cmd\e[0m"
    echo -e "\e[1;34m┌─[ Executing: \e[0;36m$cmd\e[1;34m ]\e[0m"

    local start=$(date +%s%3N)
    output=$(eval "$cmd" 2>&1)
    code=$?

    if [[ "$cmd" =~ ^(ls|ll|ls\ .*)$ ]]; then
      echo -e "\e[0;37m│ ${output//$'\n'/  }\e[0m"
    else
      i=0
      while IFS= read -r line; do
        (( i++ % 2 == 0 )) && echo -e "\e[0;37m│ $line\e[0m" || echo -e "\e[0;90m│ $line\e[0m"
      done <<< "$output"
    fi

    end=$(date +%s%3N)
    duration=$(awk "BEGIN {printf \"%.2f\", ($end - $start)/1000}")

    if [[ $code -eq 0 ]]; then
      echo -e "\e[1;34m└─[\e[1;32m✔ Done\e[1;34m ⏱ ${duration}s]\e[0m"
    else
      echo -e "\e[1;34m└─[\e[1;31m✘ Exit Code: $code\e[1;34m ⏱ ${duration}s]\e[0m"
    fi
  done
}

# Launch custom shell only in interactive sessions
[[ $- == *i* ]] && run_custom_shell

EOF

# Set secure password
read -sp "Set password for $username: " pass; echo
echo -n "$pass" | sha256sum | awk '{print $1}' > ~/.${username}_pass
chmod 600 ~/.${username}_pass

# Create login launcher
cat > ~/login-$username.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash

# Step 1: Prompt for password
pass_input=\$(termux-dialog -p -t "Login: $username" -i "Enter your password" | jq -r '.text')
[ -z "\$pass_input" ] || [ "\$pass_input" = "null" ] && {
    termux-toast -g middle -s "Cancelled"
    exit 1
}

# Step 2: Verify password hash
input_hash=\$(echo -n "\$pass_input" | sha256sum | awk '{print \$1}')
stored_hash=\$(cat ~/.${username}_pass 2>/dev/null)
[ "\$input_hash" != "\$stored_hash" ] && {
    termux-toast -g middle -s "Access denied"
    exit 1
}

# Step 3: Define private environment paths
ORIG_HOME=\$HOME
PRIVATE_HOME=\$ORIG_HOME/users/$username
mkdir -p "\$PRIVATE_HOME"

# Step 4: Launch subshell with new HOME
termux-toast -g top "Welcome $username"
env HOME="\$PRIVATE_HOME" bash --rcfile <(
cat <<'INNER_EOF'
# Custom RC file for private session
cd "\$HOME"
clear
echo -e "\e[1;32mWelcome to your private environment, $username.\e[0m"
export HOME="\$HOME"

# Source private .bashrc if exists
[ -f "\$HOME/.bashrc" ] && source "\$HOME/.bashrc"
INNER_EOF
)
EOF

chmod +x ~/login-$username.sh
