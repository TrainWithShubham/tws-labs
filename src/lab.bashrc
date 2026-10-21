PS1='\[\e[1;32m\]learner@lab\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
export EDITOR=nano

# The command log the checks read (`ran`, `ran_re`). The shell itself reports each command it ran, as bash ran it, so Tab completion and
# arrow-key recall count. The server also records what was typed (a fallback for programs that are not this shell); duplicates are harmless.
if [ -n "${LAB_HISTORY:-}" ]; then
  __tws_last=
  __tws_log() {
    local n c
    read -r n c <<<"$(HISTTIMEFORMAT= builtin history 1)"
    [ -n "$n" ] && [ "$n" != "$__tws_last" ] || return 0
    __tws_last=$n
    printf '%s\n' "$c" >> "$LAB_HISTORY" 2>/dev/null
    return 0
  }
  PROMPT_COMMAND="__tws_log${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
