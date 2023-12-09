#!/bin/bash

# Configuration script to symlink the dotfiles or clean up the symlinks.
# The script should take a target flag stating whether "build" or "clean". The
# first option will symlink all of the dotfiles and install zsh plugins.
# Otherwise, the script will simply remove all symlinks.

usage="Usage: $0 [-h] [-t <build|clean>]"

if [[ "$#" -lt 1 ]]; then
  echo "$usage"
  exit
fi

while getopts :ht: option; do
  case $option in
    h)
      echo "$usage"
      echo
      echo "OPTIONS"
      echo "-h            Output verbose usage message"
      echo "-t build      Set up dotfile symlinks and configure oh-my-zsh"
      echo "-t clean      Remove all existing dotfiles symlinks"
      exit;;
    t)
      if [[ "build" =~ ^${OPTARG} ]]; then
        BUILD=true
      elif [[ "clean" =~ ^${OPTARG} ]]; then
        BUILD=
      else
        echo "$usage" >&2
        exit 1
      fi;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      exit 1;;
    :)
      echo "Missing argument for -$OPTARG" >&2
      exit 1;;
  esac
done

declare -a FILES_TO_SYMLINK=(
  'fzf.zsh'
  'zprofile'
  'zshrc'
)

print_success() {
  if [[ $BUILD ]]; then
    # Print output in green
    printf "\e[0;32m  [✔] %s\e[0m\n" "$1"
  else
    # Print output in cyan
    printf "\e[0;36m  [✔] Unlinked %s\e[0m\n" "$1"
  fi
}

print_error() {
  if [[ $BUILD ]]; then
    # Print output in red
    printf "\e[0;31m  [✖] %s %s\e[0m\n" "$1" "$2"
  else
    # Print output in red
    printf "\e[0;31m  [✖] Failed to unlink %s %s\e[0m\n" "$1" "$2"
  fi
}

print_question() {
  # Print output in yellow
  printf "\e[0;33m  [?] %s\e[0m" "$1"
}

execute() {
  $1 &> /dev/null
  print_result $? "${2:-$1}"
}

print_result() {
  if [ "$1" -eq 0 ]; then
    print_success "$2"
  else
    print_error "$2"
  fi

  [ "$3" == "true" ] && [ "$1" -ne 0 ] && exit
}

ask_for_confirmation() {
  print_question "$1 [y/N] "
  read -r -n 1
  printf "\n"
}

answer_is_yes() {
  [[ "$REPLY" =~ ^[Yy]$ ]] \
    && return 0 \
    || return 1
}

install_zsh_syntax_highlighting() {  
  # Clone zsh-syntax-highlighting plugin if it isn't already present
  if [[ ! -d $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  fi
}

link_file() {
  local sourceFile=$1
  local targetFile=$2

  if [ ! -e "$targetFile" ]; then
    execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
  elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
    print_success "$targetFile → $sourceFile"
  else
    ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
    if answer_is_yes; then
      rm -rf "$targetFile"
      execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    else
      print_error "$targetFile → $sourceFile"
    fi
  fi
}

unlink_file() {
  local sourceFile=$1
  local targetFile=$2

  if [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
    execute "unlink $targetFile" "$targetFile"
  fi
}

if [[ $BUILD ]]; then
  brew bundle --file="$HOME/.dotfiles/Brewfile" --no-upgrade

  install_zsh_syntax_highlighting
fi

# Symlink (or unlink) the dotfiles.
for i in "${FILES_TO_SYMLINK[@]}"; do
  sourceFile="$(pwd)/$i"
  targetFile="$HOME/.$(printf "%s" "$i" | sed "s/.*\/\(.*\)/\1/g")"

  if [[ $BUILD ]]; then
    link_file $sourceFile $targetFile
  else
    unlink_file $sourceFile $targetFile
  fi
done
