#!/bin/zsh

RED="\033[0;91m"
GREEN="\033[0;92m"
YELLOW="\033[0;93m"
BLUE="\033[0;94m"
CYAN="\033[0;96m"
WHITE="\033[0;97m"
LRED="\033[1;31m"
LGREEN="\033[1;32m"
LYELLOW="\033[1;33m"
LBLUE="\033[1;34m"
LCYAN="\033[1;36m"
LWHITE="\033[1;37m"
LG="\033[0;37m"
NC="\033[0m"
REWRITELN="\033[A\r\033[K"

sed_inplace() {
  sed -i '' "$@"
}

trim() {
  echo "$1" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
}

usage() {
  echo "${GREEN}Grepp auto-installer${NC} ${CYAN}for Developers${NC}"
  echo ""
  echo "${LWHITE}USAGES${NC}"
  echo "  $0  ${LWHITE}[OPTIONS]${NC}"
  echo ""
  echo "${LWHITE}OPTIONS${NC}"
  echo "  ${LWHITE}-h, --help${NC}           Show this help message and exit"
  echo ""
  echo "  ${LWHITE}-e, --env ENVID${NC}"
  echo "                       Manually override the environment ID to use"
  echo "                       (default: random-generated)"
  echo ""
  echo "  ${LWHITE}--python-version VERSION${NC}"
  echo "                       Set the Python version to install via pyenv"
  echo "                       (default: 3.9.10)"
  echo ""
  echo "  ${LWHITE}--ruby-version VERSION${NC}"
  echo "                       Set the Ruby version to instll via rbenv"
  echo "                       (default: 2.7.5)"
  echo ""
  echo "  ${LWHITE}--node-version VERSION${NC}"
  echo "                       Set the Node version to install via nvm"
  echo "                       (default: 16.14.1)"
}

show_error() {
  echo " "
  echo "${RED}[ERROR]${NC} ${LRED}$1${NC}"
}

show_warning() {
  echo " "
  echo "${YELLOW}[WARNING]${NC} ${LYELLOW}$1${NC}"
}

show_info() {
  echo " "
  echo "${BLUE}[INFO]${NC} ${GREEN}$1${NC}"
}

show_note() {
  echo " "
  echo "${BLUE}[NOTE]${NC} $1"
}

show_important_note() {
  echo " "
  echo "${LRED}[NOTE]${NC} $1"
}

has_python() {
  "$1" -c '' >/dev/null 2>&1

  if [ "$?" -eq 127 ]
  then
    echo 0
  else
    echo 1
  fi
}

if [ $(id -u) = "0" ]
then
  sudo=''
else
  sudo='sudo'
fi

if [ $(has_python "python") -eq 1 ]
then
  python=$(which "python")
elif [ $(has_python "python3") -eq 1 ]
then
  python=$(which "python3")
elif [ $(has_python "python2") -eq 1 ]
then
  python=$(which "python2")
else
  show_error "python (for bootstrapping) is not available."
  show_info "This script assumes Python2.7/3+ is already available on your system."
  exit 1
fi

ROOT_PATH=$(pwd)
PYTHON_VERSION="3.9.10"
RUBY_VERSION="2.7.5"
NODE_VERSION="16.14.1"

while [ $# -gt 0 ]; do
  case $1 in
    -h | --help)
      usage
      exit 1
      ;;
    --python-version)
      PYTHON_VERSION=$2
      shift
      ;;
    --python-version=*)
      PYTHON_VERSION="${1#*=}"
      ;;
    --ruby-version)
      RUBY_VERSION=$2
      shift
      ;;
    --ruby-version=*)
      RUBY_VERSION="${1#*=}"
      ;;
    --node-version)
      NODE_VERSION=$2
      shift
      ;;
    --node-version=*)
      NODE_VERSION="${1#*=}"
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run '$0 --help' for usage."
      exit 1
  esac
  shift
done

install_brew() {
  if ! command -v brew > /dev/null 2>&1 
  then
    show_info "try to support auto-install on macOS using Homebrew."
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
  brew update
}

install_build_deps() {
  brew tap puma/puma
  brew tap homebrew/core
  brew tap homebrew/bundle
  brew tap homebrew/cask
  brew install jq
  brew install openssl@1.1
  brew install openjdk
  brew install awscli
  brew install ec2-api-tools
  brew install git
  brew install git-lfs
  brew install libpq
  brew install nginx
  brew install yarn
  brew install puma/puma/puma-dev
  brew install readline
  brew install zlib xz
  brew install sqlite3 gdbm
  brew install tcl-tk
  brew install postgresql@10
  brew install pkg-config
  brew install icu4c
  brew install shared-mime-info
  brew install cmake
}

initialize_git_lfs() {
  show_info "Initialize git lfs"
  git lfs install
}

install_docker() {
  show_info "Install docker"
  brew install --cask docker
}

install_rbenv() {
  if [ ! $(command -v rbenv) ] > /dev/null 2>&1
  then
    show_info "Installing rbenv..."
    set -e
    brew install rbenv ruby-build
    for PROFILE_FILE in "zshrc" "bashrc" "profile" "bash_profile"
    do 
      if [ -e "${HOME}/.${PROFILE_FILE}" ]
      then
        echo 'eval "$(rbenv init -)"' >> "${HOME}/.${PROFILE_FILE}"
      fi
    done
    set +e
    eval "$(rbenv init -)"
    curl -fsSL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-doctor | bash
  else
    show_info "rbenv is already installed."
    eval "$(rbenv init -)"
  fi
}

install_ruby() {
  if [ -z "$(rbenv versions | grep -o ${RUBY_VERSION})" ]
  then
    RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1) --with-readline-dir=$(brew --prefix readline)" rbenv install --skip-existing --keep -v "${RUBY_VERSION}"

    if [ $? -ne 0 ]
    then
      show_error "Installing the Ruby version ${RUBY_VERSION} via rbenv has failed."
      show_note "${RUBY_VERSION} is not supported by your current installation of rbenv."
      show_note "Please update rbenv or lower RUBY_VERSION in install_dev.sh script."
      exit 1
    fi
  else
    echo "${RUBY_VERSION} is already installed."
  fi
}

install_nvm() {
  eval "export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")""
  if [ ! -f $HOME/.nvm/nvm.sh ] > /dev/null 2>&1 
  then
    show_info "Installing nvm..."
    set -e
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash > /dev/null
    set +e
    eval "[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"" > /dev/null
  else
    show_info "nvm is already installed."
    eval "[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"" > /dev/null
  fi
}

install_node() {
 if [ -z "$(nvm ls ${NODE_VERSION} | grep -o ${NODE_VERSION})" ]
  then
    nvm install "${NODE_VERSION}"

    if [ $? -ne 0 ]
    then
      show_error "Installing the Node version ${NODE_VERSION} via nvm has failed."
      show_note "${NODE_VERSION} is not supported by your current installation of nvm."
      show_note "Please update nvm or lower NODE_VERSION in install_dev.sh script."
      exit 1
    fi
  else
    echo "${NODE_VERSION} is already installed."
  fi 
}

install_pyenv() {
  show_info "Checking pyenv..."
  if [ ! $(command -v pyenv) ] >/dev/null 2>&1
  then
    show_info "Installing pyenv..."
    set -e
    brew install pyenv
    for PROFILE_FILE in "zshrc" "bashrc" "profile" "bash_profile"
    do
      if [ -e "${HOME}/.${PROFILE_FILE}" ]
      then
        echo "$pyenv_init_script" >> "${HOME}/.${PROFILE_FILE}"
      fi
    done
    set +e
    eval "$pyenv_init_script"
  else
    show_info "pyenv is already installed."
    eval "$pyenv_init_script"
  fi
}

install_python() {
  if [ -z "$(pyenv versions | grep -o ${PYTHON_VERSION})" ]
  then
    export PYTHON_CONFIGURE_OPTS="--enable-framework" 
    local _prefix_openssl="$(brew --prefix openssl@1.1)"
    local _prefix_sqlite3="$(brew --prefix sqlite3)"
    local _prefix_readline="$(brew --prefix readline)"
    local _prefix_zlib="$(brew --prefix zlib)"
    local _prefix_gdbm="$(brew --prefix gdbm)"
    local _prefix_tcltk="$(brew --prefix tcl-tk)"
    local _prefix_xz="$(brew --prefix xz)"
    export CFLAGS="-I${_prefix_openssl}/include -I${_prefix_sqlite3}/include -I${_prefix_readline}/include -I${_prefix_zlib}/include -I${_prefix_gdbm}/include -I${_prefix_tcltk}/include -I${_prefix_xz}/include"
    export LDFLAGS="-L${_prefix_openssl}/lib -L${_prefix_sqlite3}/lib -L${_prefix_readline}/lib -L${_prefix_zlib}/lib -L${_prefix_gdbm}/lib -L${_prefix_tcltk}/lib -L${_prefix_xz}/lib"

    pyenv install --skip-existing -k "${PYTHON_VERSION}"
    
    if [ $? -ne 0 ]
    then
      show_error "Installing the Python version ${PYTHON_VERSION} via pyenv has failed."
      show_note "${PYTHON_VERSION} is not supported by your current installation of pyenv."
      show_note "Please update pyenv or lower PYTHON_VERSION in install_dev.sh script."
      exit 1
    fi
  else
    echo "${PYTHON_VERSION} is already installed."
  fi
}

# Begin!
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@%* ./&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@@@@                .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@                 @@@(   @@@@@@@@@@@@@@@@@@@@@@@@///@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@                   *@@@@@@@@@@           #@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@#                 @@@@@@@@@@@@                 @@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@                 @@@@@@@@@@@@@     .@, @@  @@ *@. @@@@@@@@/////////@@"
echo "@@@@@@@@@                                                   @@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@                                               .@@/     .@@@@@@@@@@@@@@@"
echo "@@@@@@@@&                                             .@@@@@@@@@@@@&&@@@@@@@@@@@"
echo "@@@@@@@@@@,                                                 @@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@(                                             @ @@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@@@                                      @   @@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@@@@@/                                  @.   @@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@@@                                   .@    @@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@@*                                   @@   .@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@@@                                   @@   &@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@@@@@                                   @@ .@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@@@@@@,                                   &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@@@@                                     (@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@                                 .@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo "@@@@.    ,&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

echo "${LGREEN}GREPP AUTO-INSTALLER FOR DEVELOPERS${NC}"

# Check prerequisites
show_info "Checking prerequisites and script dependencies..."

show_info "Installing brew..."
install_brew

show_info "Installing build dependencies..."
install_build_deps

show_info "Initializing git..."
initialize_git_lfs

if ! type "docker" > /dev/null 2>&1
then
  show_warning "docker is not available; trying to install it automatically..."
  install_docker
fi

docker compose version > /dev/null 2>&1
if [ $? -eq 0 ]
then
  DOCKER_COMPOSE="docker compose"
else
  if ! type "docker-compose" > /dev/null 2>&1
  then
    show_warning "docker-compose is not available; trying to install it automatically..."
    install_docker_compose
  fi
  DOCKER_COMPOSE="docker-compose"
fi

echo "validating Docker Desktop mount permissions..."
docker pull alpine:3.8 > /dev/null
docker run --rm -v "$HOME/.pyenv:/root/vol" alpine:3.8 ls /root/vol > /dev/null 2>&1
if [ $? -ne 0 ]
then
  show_error "You must allow mount of '$HOME' in the File Sharing preference of the Docker Desktop app."
  exit 1
fi
echo "${REWRITELN}validating Docker Desktop mount permissions: ok"

# Install rbenv
show_info "Checking rbenv..."
install_rbenv

# Install Ruby
show_info "Installing Ruby..."
install_ruby

# Install nvm
show_info "Checking nvm..."
install_nvm

# Install Node
show_info "Installing node..."
install_node

# Install pyenv
read -r -d '' pyenv_init_script <<"EOS"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOS
install_pyenv
  
# Install Python
show_info "Installing Python..."
install_python
