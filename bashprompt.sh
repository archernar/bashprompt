__git_changed() {
    local BRIGHT_BLACK="\033[90m"                  # Often used as Gray / Dim Black
    local RESET="\033[0m"
    local N 
    local sz
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        N=$(git diff --name-only HEAD | wc -l)
        if [ "$N" -gt 0 ]; then
            sz="$(git diff --name-only HEAD | paste -sd ' ')"
            echo -e "\n${BRIGHT_BLACK}├───[C]─${RESET}$sz"
        fi
    fi
}
__git_untracked() {
    local BRIGHT_BLACK="\033[90m"                  # Often used as Gray / Dim Black
    local RESET="\033[0m"
    local N 
    local sz
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        N=$(git ls-files --others --exclude-standard --exclude=.* | wc -l)
        if [ "$N" -gt 0 ]; then
            sz="$(git ls-files --others --exclude-standard --exclude=.* | paste -sd ' ')"
            echo -e "\n${BRIGHT_BLACK}├───[U]─${RESET}$sz"
        fi
    fi
}
__git_currentbranch() {
    local sz="NGR"
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        # Get the current branch name
        sz=$(git rev-parse --abbrev-ref HEAD)
        # Handle detached HEAD state
        if [ "$sz" == "HEAD" ]; then
            sz="Detached HEAD state."
        fi
    fi
    echo -e "$sz"
}

set_prompt() {
    #┌───
    #├───────
    #└──╼
    local DOLLA="\$"
    local RESET="\[\033[0m\]"
    local BLACK="\[\033[30m\]"
    local BRIGHT_BLACK="\[\033[90m\]"              # Often used as Gray / Dim Black
    local RED="\[\033[31m\]"
    local GREEN="\[\033[32m\]"
    local YELLOW="\[\033[33m\]"
    local BLUE="\[\033[34m\]"
    local MAGENTA="\[\033[35m\]"
    local CYAN="\[\033[36m\]"
    local WHITE="\[\033[37m\]"
    local BOLD="\[\033[1m\]"

    if [[ $GIT_ONELINE -eq 0 ]]; then
        PS1="${BRIGHT_BLACK}┌───[${RESET}"
    else
        PS1="${BRIGHT_BLACK}[${RESET}"
    fi
    PS1+="$(__exit_status)"
    PS1+="${BRIGHT_BLACK}]─[${BOLD}${WHITE}\u@\h${BRIGHT_BLACK}]─[${YELLOW}\w${BRIGHT_BLACK}]"
    PS1+="(\$(__git_currentbranch))"
    PS1+="\$(__git_prompt)"
    
    # Listing untracked and changed files
    if [[ $GIT_UNTRACKED -eq 1 ]]; then
        PS1+="\$(__git_untracked)"
    fi
    if [[ $GIT_CHANGED -eq 1 ]]; then
        PS1+="\$(__git_changed)"
    fi
    
    if [[ $GIT_ONELINE -eq 0 ]]; then
        PS1+="\n${BRIGHT_BLACK}└──╼ ${BOLD}${WHITE}${DOLLA}${RESET} "
    else
        PS1+=" ${DOLLA}${RESET} "
    fi

}

# Dynamic status icon (Green check on success, Red cross on failure)
__exit_status() {
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        printf "%s✓%s" "$GREEN" "$RESET"
    else
        printf "%s✗ [%s]%s" "$RED" "$exit_code" "$RESET"
    fi
}

# Git branch parser for prompt
__git_prompt() {
    local DOLLA="\$"
    local GTGT=">>"
    local SPC=" "
    local RESET="\033[0m"
    local BLACK="\033[30m"
    local BRIGHT_BLACK="\033[90m"                  # Often used as Gray / Dim Black
    local GREEN="\033[32m"
    local WHITE="\033[37m"
    local RED="\033[31m"
    local BOLD="\033[1m"
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        local current_branch=$(git rev-parse --abbrev-ref HEAD)
        if ! git rev-parse --verify "origin/$current_branch" > /dev/null 2>&1; then
            echo -e "$WHITE>> $RESET"
            return 1
        fi

        local ahead_count=$(git rev-list --count "origin/$current_branch..$current_branch")
        local behind_count=$(git rev-list --count "$current_branch..origin/$current_branch")

        # Count all changes staged and unstaged
        local allchanges_count=$(git diff --name-only HEAD | wc -l)
        N=$allchanges_count
        if [ "$allchanges_count" -eq 0 ]; then
            CHANGES="$GREEN$N>"
        else
            CHANGES="$RED$N>"
        fi

        local total=$(( ahead_count + behind_count ))

        if [ "$ahead_count" -eq 0 ] && [ "$behind_count" -eq 0 ]; then
            echo -e "$GREEN>>$CHANGES$RESET"
        else
            echo -e "$RED>>$CHANGES$RESET"
        fi
    else
        echo -e "$WHITE>>$CHANGES$RESET"
    fi
}
bashprompt() {
    GIT_ONELINE=0
    GIT_CHANGED=0
    GIT_UNTRACKED=0
    case "$1" in
        git)
            GIT_CHANGED=1
            GIT_UNTRACKED=1
            set_prompt;
            ;;
        gitsimple)
            GIT_ONELINE=1
            GIT_CHANGED=0
            GIT_UNTRACKED=0
            set_prompt;
            ;;
        simple)
            PS1="\$ "
            ;;
        minimal)
            PS1="\$ "
            ;;
        compact)
            PS1="\[\e[1;36m\]\W\[\e[0m\] \$ "
            ;;
        full)
            PS1="\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "
            ;;
        *)
            PS1="\$ "
            echo "Usage: bashprompt {git|gitsimple|simple|minimal|compact|full}"
            ;;
    esac
}

bashprompt simple

#PROMPT_COMMAND="set_prompt; $PROMPT_COMMAND"


