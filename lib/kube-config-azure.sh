#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include EcoMind/k8s-common:0.2.0 kube-config
else
    include EcoMind/k8s-common lib/kube-config.sh
fi

set_azure_profile() {
    local azure_profile_name="$1"
    # TBD
    # export AWS_PROFILE="${aws_profile_name}"
    # watch_if_exists "$HOME/.aws/config"
    # watch_if_exists "$HOME/.aws/credentials"
}

