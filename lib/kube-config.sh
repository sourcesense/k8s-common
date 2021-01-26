#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include EcoMind/k8s-common kube
else
    include EcoMind/k8s-common lib/kube.sh
fi

if type dep &>/dev/null ; then
    dep include EcoMind/k8s-common helm
else
    include EcoMind/k8s-common lib/helm.sh
fi

get_kube_server_version() {
    kubectl version --short | tail -1 | cut -d":" -f 2 | xargs
}

get_kube_client_version() {
    kubectl version --short | head | cut -d":" -f 2 | xargs
}

regenerate_token() {
    warn "Token regeneration not enabled!"
}

set_kubeconfig_profile() {
    local profile_name="$1"
    local kubeconfig_file="$HOME/.kube/profiles/${profile_name}"
    export KUBECONFIG="$kubeconfig_file"
    watch_file "$kubeconfig_file"
}

watch_if_exists() {
    local filename="$1"
    if [ -f "$filename" ]; then
        watch_file "$filename"
    fi
}

has_context() {
    local context_name="$1"
    kubectx | grep -q "$context_name"
}

prepare_and_check_k8s_context() {
    local context_prefix="$1"
    local cluster_description
    if [ -z "${AWS_PROFILE}" ]; then
        kubectx "${context_prefix}"
        cluster_description="context: $(b "$(kubectx -c)")"
    else
        local context_name="${context_prefix}-$AWS_PROFILE"
        log "Searching for accessibility of k8s context $(b "$context_name")"
        if has_context "$context_name"; then
            log "k8s context $(b "$context_name") is accessible, switching to it"
            kubectx "${context_name}"
        else
            log "k8s context $(b "$context_name") is not accessible, trying with $(b "$context_prefix")"
            context_name="$context_prefix"
            kubectx "${context_name}"
        fi
        log "Switched to k8s context $(b "$(kubectx -c)")"
        cluster_description="context: $(b "$(kubectx -c)") - AWS_PROFILE = $(b "${AWS_PROFILE}")"
    fi
    log "Checking Kubernetes accessibility - ${cluster_description}"
    if kubectl version >/dev/null 2>&1 ; then
        log "Found valid Kubernetes accessibility - ${cluster_description}"
        log "Server version: $(b "$(get_kube_server_version)")"
        log "No need to regenerate token"
    else 
        warn "Couldn't access Kubernetes right now with stored token, please fix it"
        warn "Please enter your password when prompt appears; also, $(i "there's no need to worry if direnv whines about long running .envrc script")"
        regenerate_token
    fi
}

prepare_helm_secrets_plugin() {
    prepare_helm_plugin "Helm secrets" https://github.com/futuresimple/helm-secrets
}

