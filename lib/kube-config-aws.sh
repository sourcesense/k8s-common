#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include EcoMind/k8s-common:0.2.1 kube-config
else
    include EcoMind/k8s-common lib/kube-config.sh
fi

set_aws_profile() {
    local aws_profile_name="$1"
    export AWS_PROFILE="${aws_profile_name}"
    watch_if_exists "$HOME/.aws/config"
    watch_if_exists "$HOME/.aws/credentials"
}

