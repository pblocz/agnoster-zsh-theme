# vim:ft=zsh ts=2 sw=2 sts=2 fdm=marker
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing {{{1
# A few utility functions to make it easy and re-usable to draw segmented prompts

# Colors and globals {{{2
CURRENT_BG='NONE'

PRIMARY_FG=black
PRIMARY_BG=green

SECONDARY_FG=default
SECONDARY_BG=black

OPTIONAL_FG=default # white
OPTIONAL_BG=15 # light grey

WARNING_FG=226 # yellow
CROSS_FG=red
GEAR_FG=blue


# Characters {{{2
SEGMENT_SEPARATOR="\ue0b0"
ALT_SEGMENT_SEPARATOR="\ue0b1"
REVSEGMENT_SEPARATOR="\ue0b2"
ALT_REVSEGMENT_SEPARATOR="\ue0b3"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2716"
LIGHTNING="\u26a1"
GEAR="\u2699"

# Normal prompt segments {{{2
# Begin a segment {{{3
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
# arguments: foreground-color, background-color, text
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%}"
  elif [[ $CURRENT_BG != 'NONE' && $1 == $CURRENT_BG ]]; then
    print -n "%{$bg%}%B$ALT_SEGMENT_SEPARATOR%b%{$fg%}"
  else
    print -n "%{$bg%}%{$fg%}"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}


# End the prompt, closing any open segments {{{3
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

# Reverse prompt segments {{{2
# Begin a reverse segment {{{3
# arguments: foreground-color, background-color, text
rprompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"

  if [[ $1 != $CURRENT_BG ]]; then
    print -n "%F{$1}$REVSEGMENT_SEPARATOR%{$fg%}%{$bg%}"
  else [[ $1 == $CURRENT_BG ]]
    print -n "%{$fg%}%B$ALT_REVSEGMENT_SEPARATOR%b%{$bg%}"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt, closing any open segments
rprompt_end() {
  print -n "%{%k%f%}"
  CURRENT_BG=''
}

### Prompt components {{{1
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I) {{{2
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
    ${_PROMPT}_segment $1 $2 " %(!.%{%F{yellow}%}.)$user@%m "
  fi
}

# Git: branch/detached head, dirty status {{{2
prompt_git() {
  local ref repo_path mode untracked staged unstaged uncommited symbols


  if [[ -n "$git_info" ]]; then
    # get number of files from git status
    read untracked staged unstaged <<<$(\
      git status --porcelain |\
      awk 'BEGIN {u=0;s=0;us=0}
           /^[MARCD]/ {s++}
           /^.[MD]/ {us++}
           /^\?\?/ {u++}
           END {print u,s,us}')
    if [[ "$unstaged" -ne "0" ]]; then uncommited="${unstaged}U "; fi
    if [[ "$staged" -ne "0" ]]; then uncommited="$uncommited${staged}S "; fi
    if [[ "$untracked" -ne "0" ]]; then uncommited="$uncommited${untracked}? "; fi


    # TODO: add this info from special section
    # # check if git is in any kind of special mode
    # if [[ -e "${repo_path}/BISECT_LOG" ]]; then
    #   mode=" <B>"
    # elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
    #   mode=" >M<"
    # elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" ||\
    #   -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
    #   mode=" >R>"
    # fi

    ${_PROMPT}_segment $1 $2 #  $color $PRIMARY_FG
    print -Pn " ${uncommited}"'${(e)git_info[count]}${(e)git_info[ref]}${(e)git_info[status]}${(e)git_info[warning]}'
  fi
}


# Dir: current working directory {{{2
# method to shrink folders from paradox theme
prompt_dir() {
  local pwd="${PWD/#$HOME/~}"

  if [[ "$pwd" == (#m)[/~] ]]; then
    pwd="$MATCH"
    unset MATCH
  else
    pwd="${${${${(@j:/:M)${(@s:/:)pwd}##.#?}:h}%/}//\%/%%}/${${pwd:t}//\%/%%}"
  fi
  ${_PROMPT}_segment $1 $2 " ${pwd} "
}


# Status: {{{2
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$CROSS_FG}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{$WARNING_FG}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$GEAR_FG}%}$GEAR"

  [[ -n "$symbols" ]] && ${_PROMPT}_segment $1 $2 " $symbols "
}


# Display current virtual environment {{{2
prompt_virtualenv() {
  if [[ -n $VIRTUAL_ENV ]]; then
    ${_PROMPT}_segment $1 $2
    print -Pn " $(basename $VIRTUAL_ENV) "
  fi
}


## Main prompt {{{1
prompt_agnoster_main() {
  RETVAL=$?
  CURRENT_BG='NONE'
  _PROMPT='prompt'

  prompt_status $SECONDARY_BG $SECONDARY_FG
  prompt_context $SECONDARY_BG $SECONDARY_FG
  prompt_virtualenv $SECONDARY_BG $SECONDARY_FG
  prompt_dir $PRIMARY_BG $PRIMARY_FG
  prompt_git $OPTIONAL_BG $OPTIONAL_FG
  prompt_end
}


prompt_agnoster_precmd() {

  # Get Git repository information.
  if (( $+functions[git-info] )); then
    git-info
  fi

  PROMPT='%{%f%b%k%}$(prompt_agnoster_main) '
}

prompt_agnoster_setup() {
  autoload -Uz add-zsh-hook
  # autoload -Uz vcs_info

  prompt_opts=(cr subst percent)

  add-zsh-hook precmd prompt_agnoster_precmd


  # from prezto paradox prompt theme
  # Set git-info parameters.
  zstyle ':prezto:module:git:info' verbose 'yes'
  zstyle ':prezto:module:git:status:ignore' submodules 'all'
  zstyle ':prezto:module:git:info:action' format '⁝ %s' # %s
  zstyle ':prezto:module:git:info:added' format ' ✚' # %a
  zstyle ':prezto:module:git:info:ahead' format '⬆' # %A
  zstyle ':prezto:module:git:info:behind' format '⬇' # %B
  zstyle ':prezto:module:git:info:branch' format ' %b' # %b
  zstyle ':prezto:module:git:info:commit' format ' %.7c' # %c
  zstyle ':prezto:module:git:info:remote' format '➦ %R' # %R
  zstyle ':prezto:module:git:info:deleted' format ' ✖' # %d
  zstyle ':prezto:module:git:info:dirty' format ' ⁝' # %D
  zstyle ':prezto:module:git:info:modified' format ' ✱' # %m
  zstyle ':prezto:module:git:info:position' format '%p' # %p
  zstyle ':prezto:module:git:info:renamed' format ' ➙' # %r
  zstyle ':prezto:module:git:info:stashed' format ' S' # %S
  zstyle ':prezto:module:git:info:unmerged' format ' ═' # %U
  zstyle ':prezto:module:git:info:untracked' format ' ?' # %u
  zstyle ':prezto:module:git:info:keys' format \
    'ref' '$(coalesce  "%b" "%c" "%p" )' \
    'status' '%s%A%B%U' \
    'warning' '$([[ -n "%D%S%a%d%m%r%U%u" ]] && { print -Pn " %F{$WARNING_FG}\u2757%f" })' # another \u2762
}

prompt_agnoster_setup "$@"
