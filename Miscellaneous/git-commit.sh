#!/bin/bash

# Shameless rip off of https://github.com/benc-uk/dotfiles/blob/master/backup.sh

random_fruit() {
  fruits=("🍎" "🍊" "🍋" "🍌" "🍉" "🍇" "🍓" "🍒" "🍑" "🍍" "🥝" "🍅" "🍆" "🥑" "🥦" "🥒" "🥬" "🥭" "🥔" "🥕" "🌽" "🌶" "🍎" "🌶️" "🫐" "🥥" "🍄")
  echo "${fruits[$((RANDOM % ${#fruits[@]}))]}"
}

echo -e "\e[34m»»» 📦 \e[32mBacking up repo to GitHub\e[0m"

git add .
git commit -m "$(random_fruit) $(date)"
git push

