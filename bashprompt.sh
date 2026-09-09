__parse_git_status() {
    # Verify inside git directory
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1

    local branch="" upstream="" ahead=0 behind=0
    local staged=0 unstaged=0 untracked=0
    local fileshowcount=10
    local changed_files=() untracked_files=()
    local RESET="\[\033[0m\]"
    local BRIGHT_BLACK="\[\033[90m\]"
    local RED="\[\033[31m\]"
    local GREEN="\[\033[32m\]"
    local YELLOW="\[\033[33m\]"

    # Fast single-pass status check
    while IFS= read -r line; do
        case "$line" in
            "# branch.head "*) branch="${line### branch.head }" ;;
            "# branch.ab "*) 
                local ab="${line### branch.ab }"
                ahead="${ab% -*}"; ahead="${ahead#*+}"; behind="${ab#*-}" ;;
            \?*) 
                ((untracked++))
                ((${#untracked_files[@]} < fileshowcount)) && untracked_files+=("${line#\? }") ;;
            1\ [^.]*|2\ [^.]*) 
                ((staged++)) ;;
            1\ .[^.]*|2\ .[^.]*) 
                ((unstaged++))
                ((${#changed_files[@]} < fileshowcount)) && changed_files+=("${line##* }") ;;
        esac
    done < <(git status --ignored=no --porcelain=v2 --branch 2>/dev/null)

    # Detached HEAD check
    [[ "$branch" == "(detached)" ]] && branch="Detached HEAD"

    # Action detection (rebase, merge, cherry-pick)
    local state=""
    if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
        state="|REBASE"
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
        state="|MERGE"
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
        state="|CHERRY-PICK"
    fi

    # Output branch + divergence
    local branch_col="$GREEN"
    (( ahead > 0 || behind > 0 )) && branch_col="$RED"

    GIT_PROMPT_INFO="${branch_col}(${branch}${state}"
    E1=""
    E2=""
    (( ahead > 0 )) && GIT_PROMPT_INFO+=" ↑${ahead}"
    (( behind > 0 )) && GIT_PROMPT_INFO+=" ↓${behind}"
    GIT_PROMPT_INFO+=")$RESET"

    (( ahead > 0 )) && E1+="↑${ahead}"
    (( behind > 0 )) && E2+="↓${behind}"
    E1+="$RESET"
    E2+="$RESET"

    # Summary indicators: staged (+), unstaged (*), untracked (?)
    local counts=""
    (( unstaged > 0 )) && counts+="$RED*${unstaged}$RESET"
    (( staged > 0 )) && counts+="$GREEN+${staged}$RESET"
    (( untracked > 0 )) && counts+="$YELLOW?${untracked}$RESET"
    [[ -n "$counts" ]] && GIT_PROMPT_INFO+=" [${counts}]"

    # File lists with truncation
    GIT_PROMPT_EXTRA=""
    if [[ $GIT_DETAIL -eq 0 ]]; then
        if [[ $GIT_CHANGED -eq 1 && unstaged -gt 0 ]]; then
            local flist="${changed_files[*]}"
            (( unstaged > fileshowcount )) && flist+=" ... +$((unstaged - fileshowcount)) more"
            GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[C]─$RESET${flist}"
        fi

        if [[ $GIT_UNTRACKED -eq 1 && untracked -gt 0 ]]; then
            local ulist="${untracked_files[*]}"
            (( untracked > fileshowcount )) && ulist+=" ... +$((untracked - fileshowcount)) more"
            GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[U]─$RESET${ulist}"
        fi
    else
        S1="staged (+), unstaged (*), untracked (?)"
        GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[Indicators:        ]─$RESET${S1}"
        GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[Ahead  origin:     ]─$RESET${E1}"
        GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[Behind origin:     ]─$RESET${E2}"

        if [[ $GIT_CHANGED -eq 1 && unstaged -gt 0 ]]; then
            local flist="${changed_files[*]}"
            (( unstaged > fileshowcount )) && flist+=" ... +$((unstaged - fileshowcount)) more"
            GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[* Changed Files:   ]─$RESET${flist}"
        fi

        if [[ $GIT_UNTRACKED -eq 1 && untracked -gt 0 ]]; then
            local ulist="${untracked_files[*]}"
            (( untracked > fileshowcount )) && ulist+=" ... +$((untracked - fileshowcount)) more"
            GIT_PROMPT_EXTRA+="\n$BRIGHT_BLACK├───[? Untracked:       ]─$RESET${ulist}"
        fi
    fi

    return 0
}



__build_prompt() {
    local exit_code=$? # Must be the very first line
    
    local RESET="\[\033[0m\]"
    local BRIGHT_BLACK="\[\033[90m\]"
    local RED="\[\033[31m\]"
    local GREEN="\[\033[32m\]"
    local YELLOW="\[\033[33m\]"
    local WHITE="\[\033[37m\]"
    local BOLD="\[\033[1m\]"
    local DOLLA="\$"

    # Exit icon
    local status_icon
    if [[ $exit_code -eq 0 ]]; then
        status_icon="${GREEN}✓${RESET}"
    else
        status_icon="${RED}✗ [${exit_code}]${RESET}"
    fi

    GIT_PROMPT_INFO=""
    GIT_PROMPT_EXTRA=""
    __parse_git_status

    if [[ $GIT_ONELINE -eq 1 ]]; then
        PS1="${BRIGHT_BLACK}[${RESET}${status_icon}${BRIGHT_BLACK}]─[${BOLD}${WHITE}\u@\h${BRIGHT_BLACK}]─[${YELLOW}\w${BRIGHT_BLACK}]"
        [[ -n "$GIT_PROMPT_INFO" ]] && PS1+="─${GIT_PROMPT_INFO}"
        PS1+="${RESET} ${DOLLA} "
    else
        PS1="${BRIGHT_BLACK}┌───[${RESET}${status_icon}${BRIGHT_BLACK}]─[${BOLD}${WHITE}\u@\h${BRIGHT_BLACK}]─[${YELLOW}\w${BRIGHT_BLACK}]"
        [[ -n "$GIT_PROMPT_INFO" ]] && PS1+="─${GIT_PROMPT_INFO}"
        [[ -n "$GIT_PROMPT_EXTRA" ]] && PS1+="${GIT_PROMPT_EXTRA}"
        PS1+="\n${BRIGHT_BLACK}└──╼ ${BOLD}${WHITE}${DOLLA}${RESET} "
    fi
}

bashprompt() {
    GIT_DETAIL=0
    GIT_ONELINE=0
    GIT_CHANGED=0
    GIT_UNTRACKED=0
    PROMPT_COMMAND="__build_prompt"

    case "$1" in
        git)
            GIT_CHANGED=1
            GIT_UNTRACKED=1
            ;;
        gitsimple)
            GIT_ONELINE=1
            ;;
        detail)
            GIT_CHANGED=1
            GIT_UNTRACKED=1
            GIT_DETAIL=1
            ;;
        compact)
            PROMPT_COMMAND=""
            PS1="\[\e[1;36m\]\W\[\e[0m\] \$ "
            ;;
        full)
            PROMPT_COMMAND=""
            PS1="\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ "
            ;;
        simple|minimal|*)
            PROMPT_COMMAND=""
            PS1="\$ "
            ;;
    esac
}

# Default initialization
bashprompt simple
