#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include EcoMind/k8s-common kube-config
else
    include EcoMind/k8s-common lib/kube-config.sh
fi

req_ver aws "2." awscli

set_aws_profile() {
    local aws_profile_name="$1"
    export AWS_PROFILE="${aws_profile_name}"
    watch_if_exists "$HOME/.aws/config"
    watch_if_exists "$HOME/.aws/credentials"
}

