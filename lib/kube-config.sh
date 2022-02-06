#!/usr/bin/env bash

if type dep &>/dev/null; then
    dep include EcoMind/k8s-common kube
else
    include EcoMind/k8s-common lib/kube.sh
fi

if type dep &>/dev/null; then
    dep include EcoMind/k8s-common helm
else
    include EcoMind/k8s-common lib/helm.sh
fi

get_kube_server_version() {
    kubectl version --short | tail -1 | cut -d":" -f 2 | xargs
}

get_kube_client_version() {
    kubectl version --client=true --short | head | cut -d":" -f 2 | xargs
}

ab() {
    # Accent + bold
    green "$(b "$*")"
}

source_if_exists() {
    local whatToSource="$1"
    # shellcheck disable=SC1090
    [ -e "$whatToSource" ] && . "$whatToSource"
}

ensure_asdf() {
    if exists asdf; then
        # Ensure that asdf integration is installed
        source_if_exists "$HOME/.asdf/asdf.sh"
        if exists brew; then
            source_if_exists "$(brew --prefix asdf)/libexec/asdf.sh"
        fi
    else
        whine "asdf not installed"
    fi
}

ensure_asdf_plugin() {
    local pluginName="$1"
    if ensure_asdf; then
        if ! (asdf plugin-list | grep -q "$pluginName"); then
            asdf plugin-add "$pluginName" >/dev/null 2>&1
        fi
    else
        whine "Can't install plugin $(ab "$pluginName") in asdf"
    fi
}

ensure_asdf_plugin_version() {
    local pluginName="$1"
    local version="$2"
    if ensure_asdf_plugin "$pluginName"; then
        log "Ensuring that $(ab "$pluginName") version $(ab "$version") is installed in asdf"
        if asdf shim-versions "$pluginName" | grep -q "version"; then
            log "Version $(ab "$version") of $(ab "$pluginName") is already installed"
        else
            asdf plugin-update "$pluginName" >/dev/null 2>&1
            if asdf install "$pluginName" "$version" >/dev/null 2>&1; then
                log "$(ab "$pluginName") version $(ab "$version") is installed in asdf"
            else
                whine "Couldn't install $(ab "$pluginName") version $(ab "$version") in asdf"
            fi
        fi
    fi
}

set_asdf_kubectl_version() {
    local version="$1"
    rawVersion="$(echo "$version" | cut -c2-)"
    if ensure_asdf_plugin_version kubectl "$rawVersion"; then
        log "Setting kubectl version $(ab "$rawVersion") in asdf as shell (env) version"
        if asdf shell kubectl "$rawVersion"; then
            log "Successfully set kubectl version $(ab "$rawVersion") in asdf as shell (env) version"
        else
            whine "Couldn't set kubectl version $(b "$rawVersion") in asdf as shell (env) version"
        fi
    else
        whine "kubectl version $(ab "$rawVersion") is not installed in asdf and couldn't install"
    fi
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

prepare_and_check_k8s_context_generic() {
    local context_name="${1:-"${CLUSTER_NAME}"}"
    local cluster_description

    log "Searching for accessibility of k8s context $(ab "${context_name}")"
    if has_context "${context_name}"; then
        log "k8s context $(ab "${context_name}") is accessible, switching to it"
        kubectl config set-context "${context_name}" >/dev/null 2>&1
    else
        whine "k8s context $(b "${context_name}") is not accessible, check your env"
    fi
    cluster_description="$(green "context: $(b "$(kubectx -c)")")"
    log "Switched to k8s ${cluster_description}"

    log "Checking Kubernetes accessibility - ${cluster_description}"
    versionOutput="$(kubectl version --short 2>/dev/null)"
    if (("$(echo "$versionOutput" | wc -l)" >= 2)); then
        log "Found valid Kubernetes accessibility - ${cluster_description}"
        serverVersion="$(echo "$versionOutput" | tail -1 | cut -d":" -f 2 | xargs)"
        log "Server version: $(ab "$serverVersion")"
        set_asdf_kubectl_version "$serverVersion"
        log "Done! No version skew between client version $(ab "$(get_kube_client_version)") and server version $(ab "$serverVersion")"
    else
        whine "Couldn't access Kubernetes right now, please fix it, or retry running a $(b "direnv reload")"
    fi
}

# deprecated
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
    if kubectl version >/dev/null 2>&1; then
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
