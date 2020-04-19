#!/bin/bash

### GENERAL FUNCTIONS FOR ALL INSTALLS

# Don't store command history.
unset HISTFILE

# # This block allows you to echo a line number for a failure.
set -eE -o functrace
err_report() {
  local lineno=$1
  local msg=$2
  echo "$0 script Failed at $lineno: $msg"
}
trap 'err_report ${LINENO} "$BASH_COMMAND"' ERR

if [[ ! -z "$firehawksecret" ]]; then
  echo "Vagrant: firehawksecret encrypted env var found"
else
  echo "Vagrant: No firehawk secret env var provided, will prompt user for input."
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
        printf "\n** CTRL-C ** EXITING...\n"
        exit
}
function to_abs_path {
    local target="$1"
    if [ "$target" == "." ]; then
        echo "$(pwd)"
    elif [ "$target" == ".." ]; then
        echo "$(dirname "$(pwd)")"
    else
        echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
    fi
}
# This is the directory of the current script
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
SCRIPTDIR=$(to_abs_path $SCRIPTDIR)
printf "\n...checking scripts directory at $SCRIPTDIR\n\n"
# source an exit test to bail if non zero exit code is produced.
. $SCRIPTDIR/exit_test.sh

argument="$1"

echo "Argument $1"
echo ""
ARGS=''

cd /deployuser

### Get s3 access keys from terraform ###

tf_action="apply"
tf_init=false
init_vm_config=true

optspec=":h-:"

parse_opts () {
    local OPTIND
    OPTIND=0
    while getopts "$optspec" optchar; do
        case "${optchar}" in
            -)
                case "${OPTARG}" in
                    dev)
                        ARGS='--dev'
                        echo "using dev environment"
                        source ./update_vars.sh --dev; exit_test
                        ;;
                    prod)
                        ARGS='--prod'
                        echo "using prod environment"
                        source ./update_vars.sh --prod; exit_test
                        ;;
                    sleep)
                        tf_action='sleep'
                        ;;
                    destroy)
                        tf_action='destroy'
                        ;;
                    no-tf)
                        tf_action='none'
                        ;;
                    tf-action)
                        tf_action="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        echo "tf_action set: $tf_action"
                        ;;
                    tf-action=*)
                        tf_action=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        echo "tf_action set: $tf_action"
                        ;;
                    tf-init)
                        tf_init="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        echo "tf_init set: $tf_init"
                        ;;
                    tf-init=*)
                        tf_init=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        echo "tf_init set: $tf_init"
                        ;;
                    init-vm-config)
                        init_vm_config="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                        opt="${OPTARG}"
                        echo "init_vm_config set: $init_vm_config"
                        ;;
                    init-vm-config=*)
                        init_vm_config=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        echo "init_vm_config set: $init_vm_config"
                        ;;
                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Unknown option --${OPTARG}" >&2
                        fi
                        ;;
                esac;;
            h)
                help
                ;;
            *)
                if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                    echo "Non-option argument: '-${OPTARG}'" >&2
                fi
                ;;
        esac
    done
}
parse_opts "$@"



if [[ -z $TF_VAR_envtier ]] ; then
  echo "Error! you must specify an environment --dev or --prod" 1>&2
  exit 64
else
  echo "init_vm_config: $init_vm_config"
  if [[ "$init_vm_config" == true ]]; then
    echo "...Init VM's"
    echo "...Provision PGP / Keybase"
    $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-010-keybase.sh $ARGS; exit_test
    echo "...Provision Local VM's"
    $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-020-init.sh $ARGS; exit_test
  else
    echo "...Bypassing Init VM's"
  fi

  if [[ "$tf_action" == "destroy" ]]; then


    echo "...Currently running instances: scripts/aws-running-instances.sh"
    $TF_VAR_firehawk_path/scripts/aws-running-instances.sh
    printf "\n...Currently existing users in the aws account"
    aws iam list-users
    echo ""
    echo "...Use state backup for destroy.  This shouldn't care if a deployment failed last"
    cp -fv terraform.tfstate.backup terraform.tfstate
    ls -ltriah

    # echo "...Terraform refresh"
    # terraform refresh -lock=false; exit_test

    echo "...Terraform destroy"
    terraform destroy -lock=false --auto-approve; exit_test
  fi

  if [[ "$tf_init" == true ]]; then
    echo "...Currently running instances: scripts/aws-running-instances.sh"
    $TF_VAR_firehawk_path/scripts/aws-running-instances.sh
    echo ""
    
    echo "...Terraform Init"
    terraform init; exit_test # Required to initialise any new modules
  fi

  echo "TF_VAR_taint_single: $TF_VAR_taint_single"
  cat $TF_VAR_secrets_path/config-override-$TF_VAR_envtier
  echo ""

  IFS=' ' # need to define whitespace seperator

  eval TF_VAR_taint_single=${TF_VAR_taint_single}
  export TF_VAR_taint_single=${TF_VAR_taint_single}
  # if [[ "$TF_VAR_taint_single"=='""' ]]; then echo 'unset TF_VAR_taint_single'; unset TF_VAR_taint_single; fi
  # if [[ "$TF_VAR_taint_single"=="" ]]; then echo 'unset TF_VAR_taint_single'; unset TF_VAR_taint_single; fi

  if [[ "$tf_action" == "apply" ]]; then

    if [ ! -z "$TF_VAR_taint_single" ]; then
      terraform state list
      # Iterate the string variable using for loop
      for item in $TF_VAR_taint_single; do echo "terraform taint $item"; done
      echo "...Terraform refresh"
      terraform refresh -lock=false; exit_test
      echo "...Finding Resources to taint"
      found=false
      for item in $TF_VAR_taint_single; do
        set -x
        # problems with grepping for predefined strings with []
        # if terraform state list | grep -q $item; then 
        #   echo "Resource exists, will taint."
        #   found=true
        # fi
        terraform taint -lock=false $item || echo "Suppress Exit Code"
      done
      if [ "$found" == false ]; then echo "No Resources were Tainted"; fi
    fi

    echo "...Currently running instances: scripts/aws-running-instances.sh"
    $TF_VAR_firehawk_path/scripts/aws-running-instances.sh
    echo ""
  
    echo "...Start Terraform"

    echo "...Terraform refresh"
    terraform refresh -lock=false; exit_test
    echo "...Terraform state list"
    terraform state list
    echo "...Terraform apply"
    terraform apply -lock=false --auto-approve; exit_test
    
  elif [[ "$tf_action" == "sleep" ]]; then
    echo "...Currently running instances: scripts/aws-running-instances.sh"
    $TF_VAR_firehawk_path/scripts/aws-running-instances.sh
    echo ""

    echo "...Terraform refresh"
    terraform refresh -lock=false; exit_test

    echo "...Terraform sleep"
    terraform apply -lock=false --auto-approve -var sleep=true
  elif [[ "$tf_action" == "destroy" ]]; then
    # echo "...Currently running instances: scripts/aws-running-instances.sh"
    # $TF_VAR_firehawk_path/scripts/aws-running-instances.sh
    # printf "\n...Currently existing users in the aws account"
    # aws iam list-users
    # echo ""

    # echo "...Terraform refresh"
    # terraform refresh -lock=false; exit_test

    # echo "...Terraform destroy"
    # terraform destroy -lock=false --auto-approve; exit_test
  fi



  if [[ "$deadline_action" == "stop" ]]; then
    ansible-playbook -i "$TF_VAR_inventory" ansible/deadline-db-stop.yaml -v; exit_test
  elif [[ "$deadline_action" == "start" ]]; then
    ansible-playbook -i "$TF_VAR_inventory" ansible/deadline-db-start.yaml -v; exit_test
  fi


  # After this point provisioning will now execute from TF.
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-030-tf-s3user-deadlinercs.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-040-ssh-routes-nfs-houdini-license-repository.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-050-localworkstation-s3user.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-060-localworkstation-user-deadline.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-070-localworkstation-houdini.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-080-vpn.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-090-cloudmounts.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-100-cloudnodes-localmounts.sh $ARGS; exit_test
  # $TF_VAR_firehawk_path/scripts/init-openfirehawkserver-110-localworkstation-cloudmounts.sh $ARGS; exit_test
fi

echo "$(date) Finished a run" | tee -a tmp/log.txt
printf '\n...Show previous 5 runs\n'
tail -n 5 tmp/log.txt

# only if there are tf actions do we check running instances, otherwise we can't asume the aws cli is installed yet when none
echo "tf_action: $tf_action"
if [ "$tf_action" != "none" ]; then 
  echo "...Currently running instances: scripts/aws-running-instances.sh"
  $TF_VAR_firehawk_path/scripts/aws-running-instances.sh
  echo ""

  lines=$($TF_VAR_firehawk_path/scripts/aws-running-instances.sh | wc -l)
  if [ "$lines" -gt "0" ]; then
    echo "instances are running"
  else
    echo "instances are not running"
  fi

  # test if the destroy command worked
  if [ "$lines" -gt "0" ] && [[ "$tf_action" == "destroy" ]]; then 
    echo "failed to destroy all running instances for the account"
    exit 1
  fi

  printf "\n...Currently existing users in the aws account"
  aws iam list-users
  echo ""

  user_present=$(aws iam list-users | grep -c "deadline_spot_deployment_user") || echo "Suppress Exit Code"
  if [ "$user_present" -gt "0" ]; then
    echo "deadline_spot_deployment_user is present"
  else
    echo "deadline_spot_deployment_user not present"
  fi

  if [ "$user_present" -gt "0" ] && [[ "$tf_action" == "destroy" ]]; then 
    echo "failed to destroy existing deadline_spot_deployment_user for the account"
    exit 1
  fi
fi