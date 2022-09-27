#!/usr/bin/env bash

if type dep &>/dev/null; then
    dep include EcoMind/k8s-common kube
    dep include EcoMind/k8s-common helm
    dep include log2/shell-common asdf
else
    include EcoMind/k8s-common lib/helm.sh
    include EcoMind/k8s-common lib/kube.sh
    include log2/shell-common lib/asdf.sh
fi

req_no_ver head tail cut xargs
req grep

get_kube_server_version() {
    kubectl version --short | tail -1 | cut -d":" -f 2 | xargs
}

get_kube_client_version() {
    kubectl version --client=true --short | head | cut -d":" -f 2 | xargs
}

set_asdf_kubectl_version() {
    local version="$1"
    # NOTE: next line will drop any eventual asdf version containeing dash and plus, installing instead the stripped version
    rawVersion="$(echo "$version" | cut -c2- | cut -d- -f1 | cut -d+ -f1)"
    ensure_asdf_plugin_version_shell kubectl "$rawVersion"
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
    kubectl config get-contexts | grep -q "$context_name"
}

_set_context() {
    local context_name="$1"
    kubectl config set-context "${context_name}" >/dev/null 2>&1
}

_describe_context() {
    a "context: $(b "$(kubectl config current-context)")"
}

_check_and_set_kubectl_version() {
    cluster_description="${cluster_description:-$(_describe_context)}"
    log "Switched to k8s ${cluster_description}"
    log "Checking Kubernetes accessibility - ${cluster_description}"
    versionOutput="$(kubectl version --short 2>/dev/null)"
    if (("$(echo "$versionOutput" | grep -ic "server")" >= 1)); then
        log "Found valid Kubernetes accessibility - ${cluster_description}"
        serverVersion="$(echo "$versionOutput" | tail -1 | cut -d":" -f 2 | xargs)"
        log "Server version: $(ab "$serverVersion")"
        if exists asdf; then
            set_asdf_kubectl_version "$serverVersion"
            log "Done! No version skew between client version $(ab "$(get_kube_client_version)") and server version $(ab "$serverVersion")"
        else
            warn "Could not set kubectl version via asdf, asdf is not available."
            warn "Will use current kubectl version $(ab "$(get_kube_client_version)")"
            warn "Beware: this may produce version skew issues with Kubernetes server."
        fi
    else
        warn "$(red "BEWARE: at this point, Kubernetes should be reachable, but it's not... Couldn't access Kubernetes right now, please fix it, or retry running a $(b "direnv reload")")"
    fi
}

prepare_and_check_k8s_context_generic() {
    local context_name="${1:-"${CLUSTER_NAME}"}"

    log "Searching for accessibility of k8s context $(ab "${context_name}")"
    if has_context "${context_name}"; then
        log "k8s context $(ab "${context_name}") is accessible, switching to it"
        _set_context "${context_name}"
    else
        whine "k8s context $(ab "${context_name}") is not accessible, check your env"
    fi

    _check_and_set_kubectl_version
}

# deprecated
prepare_and_check_k8s_context() {
    local context_prefix="$1"
    local cluster_description
    if [ -z "${AWS_PROFILE}" ]; then
        _set_context  "${context_prefix}"
        cluster_description="$(_describe_context)"
    else
        local context_name="${context_prefix}-$AWS_PROFILE"
        log "Searching for accessibility of k8s context $(ab "$context_name")"
        if has_context "$context_name"; then
            log "k8s context $(ab "$context_name") is accessible, switching to it"
            _set_context "${context_name}"
        else
            log "k8s context $(ab "$context_name") is not accessible, trying with $(ab "$context_prefix")"
            context_name="$context_prefix"
            _set_context "${context_name}"
        fi
        log "Switched to k8s context $(ab "$(kubectl config current-context)")"
        cluster_description="$(_describe_context) - AWS_PROFILE = $(ab "${AWS_PROFILE}")"
    fi
    _check_and_set_kubectl_version "$cluster_description"
}

prepare_helm_secrets_plugin() {
    prepare_helm_plugin "Helm secrets" https://github.com/futuresimple/helm-secrets
}
