#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include EcoMind/k8s-common kube-config
else
    include EcoMind/k8s-common lib/kube-config.sh
fi

req gcloud

set_gcloud_profile() {
    local gcloud_profile_name="$1"
    export CLOUDSDK_ACTIVE_CONFIG_NAME="${gcloud_profile_name}"
    watch_if_exists "$HOME/.config/gcloud/configurations/config_${gcloud_profile_name}"
}
