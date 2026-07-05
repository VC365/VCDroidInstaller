#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname "$0")" && pwd)"
name="vcdroid-installer"

install_crystal()
{
    echo -e "${YELLOW} $name Installing...${NC}"
    if [ ! -f "$SCRIPT_DIR/bin/$name" ]; then
        shards build --release -p || { echo "${RED}Build failed${NC}"; exit 1; }
    fi
    sudo install -m 755 "$SCRIPT_DIR/bin/$name" "/usr/bin/"
    echo -e "${GREEN} $name Installed!${NC}"
}
uninstall() {
    sudo rm -f "/usr/bin/$name" &> /dev/null
    echo -e "${RED} $name Deleted!${NC}"
}
main()
{
  if [ "$1" == "install" ]; then
    install_crystal
  elif [ "$1" == "uninstall" ]; then
      uninstall
  else
      echo -e "${RED} Options $0 { install | uninstall }${NC}"
      exit 1
  fi
}
main "$@"