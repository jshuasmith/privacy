#!/bin/sh

##
# Wrapper for various setup scripts included in the docker-mailserver
#

CRI=

_check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Curently docker-mailserver doesn't support podman's rootless mode, please run this script as root user." 
    exit 1
  fi
}

if [ -z "$CRI" ]; then
  if [ ! -z "$(command -v docker)" ]; then
    CRI=docker
  elif [ ! -z "$(command -v podman)" ]; then
    CRI=podman
    _check_root
  else
    echo "No Support Container Runtime Interface Detected."
    exit 1
  fi
fi

INFO=$($CRI ps \
  --no-trunc \
  --format="{{.Image}} {{.Names}} {{.Command}}" | \
  grep "supervisord -c /etc/supervisor/supervisord.conf")

IMAGE_NAME=$(echo $INFO | awk '{print $1}')
CONTAINER_NAME=$(echo $INFO | awk '{print $2}')
DEFAULT_CONFIG_PATH="$(pwd)/config"
USE_CONTAINER=false

_update_config_path() {
  if [ ! -z "$CONTAINER_NAME" ]; then
    VOLUME=$(docker inspect $CONTAINER_NAME \
      --format="{{range .Mounts}}{{ println .Source .Destination}}{{end}}" | \
      grep "/tmp/docker-mailserver$" 2>/dev/null)
  fi

  if [ ! -z "$VOLUME" ]; then
    CONFIG_PATH=$(echo $VOLUME | awk '{print $1}')
  fi
}

if [ -z "$IMAGE_NAME" ]; then
  if [ "$CRI" = "docker" ]; then
    IMAGE_NAME=tvial/docker-mailserver:latest
  elif [ "$CRI" = "podman" ]; then
    IMAGE_NAME=docker.io/tvial/docker-mailserver:latest
  fi
fi

_inspect() {
  if _docker_image_exists "$IMAGE_NAME"; then
    echo "Image: $IMAGE_NAME"
  else
    echo "Image: '$IMAGE_NAME' can’t be found."
  fi
  if [ -n "$CONTAINER_NAME" ]; then
    echo "Container: $CONTAINER_NAME"
    echo "Config mount: $CONFIG_PATH"
  else
    echo "Container: Not running, please start docker-mailserver."
  fi
}

_usage() {
  echo "Usage: $0 [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image, by default
                    'tvial/docker-mailserver:latest' for docker, and 
                    'docker.io/tvial/docker-mailserver:latest' for podman.

  -c CONTAINER_NAME The name of the running container.

  -p PATH           config folder path (default: $(pwd)/config)

SUBCOMMANDS:

  email:

    $0 email add <email> [<password>]
    $0 email update <email> [<password>]
    $0 email del <email>
    $0 email restrict <add|del|list> <send|receive> [<email>]
    $0 email list

  alias:
    $0 alias add <email> <recipient>
    $0 alias del <email> <recipient>
    $0 alias list

  config:

    $0 config dkim <keysize> (default: 2048)
    $0 config ssl <fqdn>

  relay:

    $0 relay add-domain <domain> <host> [<port>]
    $0 relay add-auth <domain> <username> [<password>]
    $0 relay exclude-domain <domain>

  debug:

    $0 debug fetchmail
    $0 debug fail2ban [<unban> <ip-address>]
    $0 debug show-mail-logs
    $0 debug inspect
    $0 debug login <commands>
"
  exit 1
}

_docker_image_exists() {
  if ${CRI} history -q "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

if [ -t 1 ] ; then
  USE_TTY="-ti"
fi

_docker_image() {
  if [ "$USE_CONTAINER" = true ]; then
    # Reuse existing container specified on command line
    ${CRI} exec ${USE_TTY} "$CONTAINER_NAME" "$@"
  else
    # Start temporary container with specified image
    if ! _docker_image_exists "$IMAGE_NAME"; then
      echo "Image '$IMAGE_NAME' not found. Pulling ..."
      ${CRI} pull "$IMAGE_NAME"
    fi

    ${CRI} run \
      --rm \
      -v "$CONFIG_PATH":/tmp/docker-mailserver \
      ${USE_TTY} "$IMAGE_NAME" $@
  fi
}

_docker_container() {
  if [ -n "$CONTAINER_NAME" ]; then
    ${CRI} exec ${USE_TTY} "$CONTAINER_NAME" "$@"
  else
    echo "The docker-mailserver is not running!"
    exit 1
  fi
}

while getopts ":c:i:p:" OPT; do
  case $OPT in
    c)
      CONTAINER_NAME="$OPTARG"
      USE_CONTAINER=true # Container specified, connect to running instance
      ;;
    i)
      IMAGE_NAME="$OPTARG"
      ;;
    p)
      case "$OPTARG" in
      /*)
          WISHED_CONFIG_PATH="$OPTARG"
          ;;
      *)
          WISHED_CONFIG_PATH="$(pwd)/$OPTARG"
          ;;
      esac
      if [ ! -d "$WISHED_CONFIG_PATH" ]; then
        echo "Directory doesn't exist"
        _usage
        exit 1
      fi
      ;;
   \?)
     echo "Invalid option: -$OPTARG" >&2
     ;;
  esac
done

if [ ! -n "$WISHED_CONFIG_PATH" ]; then
  # no wished config path
  _update_config_path

  if [ ! -n "$CONFIG_PATH" ]; then
    CONFIG_PATH=$DEFAULT_CONFIG_PATH
  fi
else
  CONFIG_PATH=$WISHED_CONFIG_PATH
fi

shift $((OPTIND-1))

case $1 in

  email)
    shift
    case $1 in
      add)
        shift
        _docker_image addmailuser $@
        ;;
      update)
        shift
        _docker_image updatemailuser $@
        ;;
      del)
        shift
        _docker_image delmailuser $@
        ;;
      restrict)
        shift
        _docker_container restrict-access $@
        ;;
      list)
        _docker_image listmailuser
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  alias)
    shift
    case $1 in
        add)
          shift
          _docker_image addalias $@
          ;;
        del)
          shift
          _docker_image delalias $@
          ;;
        list)
          shift
          _docker_image listalias $@
          ;;
        *)
          _usage
          ;;
    esac
    ;;

  config)
    shift
    case $1 in
      dkim)
        _docker_image generate-dkim-config $2
        ;;
      ssl)
        _docker_image generate-ssl-certificate "$2"
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  relay)
    shift
    case $1 in
      add-domain)
        shift
        _docker_image addrelayhost $@
        ;;
      add-auth)
        shift
        _docker_image addsaslpassword $@
        ;;
      exclude-domain)
        shift
        _docker_image excluderelaydomain $@
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  debug)
    shift
    case $1 in
      fetchmail)
        _docker_image debug-fetchmail
        ;;
      fail2ban)
        shift
        _docker_container fail2ban $@
        ;;
      show-mail-logs)
        _docker_container cat /var/log/mail/mail.log
        ;;
      inspect)
        _inspect
        ;;
      login)
        shift
        if [ -z "$1" ]; then
          _docker_container /bin/bash
        else
          _docker_container /bin/bash -c "$@"
        fi
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  *)
    _usage
    ;;
esac
