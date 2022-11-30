#!/usr/bin/env bash

# Built on top of Maciej Radzikowski's excellent Minimal Safe Bash Template
# https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [--output-name MySealedSecret.yaml] [--output-dir manifests/dir/] [--namespace kube-system] [--temp-secret tmp.yaml] --secret-name mySecret input.env

Takes a .env file and creates a SealedSecret resource

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-c, --cluster   Makes a cluster wide secret
-f, --from-file Creates a secret from a single file (for multiline secrets)
--secret-name   Name of final secret
--namespace     (opt) Namespace for final secert. Defaults to secret-name
--output-name   (opt) Name of final file. Defaults to SealedSecret.yaml
--output-dir    (opt) Where to put the sealed secret (no trailing slash). Defaults to current dir .
--temp-secret   (opt) Override default temp secret name to prevent clashes (secret.yaml)
--cert-path     (opt) Path to the public certificate to use for encryption
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
  msg "Cleaning up temp files..."
  msg "rm -f $(pwd)/${temp_secret}"
  rm -f $(pwd)/${temp_secret}
  msg "rm -f $(pwd)/_TempSealedSecret.yaml"
  rm -f $(pwd)/_TempSealedSecret.yaml
  msg "Done"
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  dry=0
  output_dir='.'
  output_name='SealedSecret.yaml'
  temp_secret='secret.yaml'
  secret_name=''
  namespace=''
  cluster_wide="namespace-wide"
  from_file=0
  cert_path=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    -c | --cluster) cluster_wide="cluster-wide" ;;
    -f | --from-file) from_file="1" ;;
    --no-color) NO_COLOR=1 ;;
    --output-dir)
      output_dir="${2-}"
      shift
      ;;
    --output-name)
      output_name="${2-}"
      shift
      ;;
    --temp-secret)
      temp_secret="${2-}"
      shift
      ;;
    --secret-name)
      secret_name="${2-}"
      shift
      ;;
    --namespace)
      namespace="${2-}"
      shift
      ;;
    --cert-path)
      cert_path="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${secret_name-}" ]] && die "Missing required parameter: secret-name"
  [[ -z "${namespace-}" ]] && namespace=${secret_name} # default to secret_name if absent
  [[ ${#args[@]} -eq 0 ]] && die "Missing input .env file"

  return 0
}

parse_params "$@"
setup_colors

# script logic here
msg "${RED}Read parameters:${NOFORMAT}"
msg "- output_dir:  ${output_dir}"
msg "- output_name: ${output_name}"
msg "- temp_secret: ${temp_secret}"
msg "- secret_name: ${secret_name}"
msg "- namespace:   ${namespace}"
msg "- cluster-wide:${cluster_wide}"
msg "- from-file:   ${from_file}"
msg "- cert-path:   ${cert_path}"
msg "- arguments:   ${args[*]-}"
msg "- script dir:  ${script_dir}"
msg "- pwd:         $(pwd)"
msg ""

if [ ${from_file} -eq 0 ]; then
  msg "Creating temp secret "$(pwd)/${temp_secret}" from env file ${args[0]}"
  kubectl create secret generic ${secret_name} --dry-run=client --from-env-file="${args[0]}" -o yaml >"$(pwd)/${temp_secret}"
else
  msg "Creating single temp secret "$(pwd)/${temp_secret}" from file ${args[0]}"
  kubectl create secret generic ${secret_name} --dry-run=client --from-file=${secret_name}="${args[0]}" -o yaml >"$(pwd)/${temp_secret}"
fi

if [ -z ${cert_path} ]; then
  msg "Creating sealed secret for namespace "${namespace}" as $(pwd)/_TempSealedSecret.yaml"
  msg "This is a ${cluster_wide} secret"
  kubeseal -n "${namespace}" --scope ${cluster_wide} -o yaml <"$(pwd)/${temp_secret}" >"$(pwd)/_TempSealedSecret.yaml"
else
  msg "Creating sealed secret for namespace "${namespace}" as $(pwd)/_TempSealedSecret.yaml"
  msg "This is a ${cluster_wide} secret"
  kubeseal --cert ${cert_path} -n "${namespace}" --scope ${cluster_wide} -o yaml <"$(pwd)/${temp_secret}" >"$(pwd)/_TempSealedSecret.yaml"
fi

msg "Renaming $(pwd)/_TempSealedSecret.yaml to final name of ${output_dir}/${output_name}"
mv $(pwd)/_TempSealedSecret.yaml ${output_dir}/${output_name}
