#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include log2/shell-common log
else
    include log2/shell-common lib/log.sh
fi

req_no_ver kubectl wc

k() {
    local params=("$@")
    kubectl --namespace "$NAMESPACE" "${params[@]}"
}

wait_for_pod() {
    local pod_name="$1"
    local wait_time="${2:-2m}"
    wait_for_state "pod/$pod_name" "$wait_time" Ready "pod $(b "$pod_name")"
}

wait_for_deployment() {
    local dep_name="$1"
    local wait_time="${2:-2m}"
    wait_for_state "deployment/$dep_name" "$wait_time" available "deployment $(b "$dep_name")"
}

wait_for_statefulset() {
    local ss_name="$1"
    local wait_time="${2:-2m}"
    # Not yet feasible, see https://github.com/kubernetes/kubernetes/issues/79606
    # wait_for_state "statefulset/$ss_name" "$wait_time" Ready "statefulset $(b "$ss_name")"
    local resource_description="statefulset $(b "$ss_name")"
    local state="Ready"
    log "Can't wait for $resource_description to become $(b "$state")... (see $(i https://github.com/kubernetes/kubernetes/issues/79606))"
}

wait_for_state() {
    local what="$1"
    local wait_time="${2:-2m}"
    local state="$3"
    local resource_description="$4"
    log "Waiting $(b "$wait_time") for $resource_description to become $(b "$state")..."
    if k wait "--for=condition=$state" --timeout=2m "$what" ; then
        log "$resource_description is confirmed to be $(b "$state")"
    else
        whine "Could not wait for $resource_description to be $(b "$state"), exiting right now"
    fi
}

has_single_pod() {
    local unique_pod_selector="$1"
    return $(( $(k get pod --output=jsonpath={.items..metadata.name} -l "$unique_pod_selector" | wc -l) == 1 ))
}

check_single_pod() {
    local unique_pod_selector="$1"
    log "Searching for pods matched by $(b "$unique_pod_selector") (expected to be unique)"
    if has_single_pod "$unique_pod_selector" ; then
        local target_pod="$(kubectl get pod --output=jsonpath={.items..metadata.name} -l "$unique_pod_selector")"
        log "Found a single pod matching selector - pod name: $(b "$target_pod")"
    else
        whine "Could not find a single pod matching given selector (matching pods: $(b "$(k get pod --output=jsonpath={.items..metadata.name} -l "$unique_pod_selector" | wc -l)"))"
    fi
}

get_single_pod_name() {
    local unique_pod_selector="$1"
    if has_single_pod "$unique_pod_selector" ; then
        k get pod --output=jsonpath={.items..metadata.name} -l "$unique_pod_selector"
    else
        exit 1
    fi
}

kube_resource_exists() {
    local resource_name="$1"
    k get "$resource_name" >/dev/null 2>&1 
}

create_namespace_if_not_exists() {
    local namespace="$1"
    if kube_resource_exists "namespace/$namespace" ; then
        log "Namespace $(b "$namespace") already exists, no need to create it"
    else
        log "Namespace $(b "$namespace") not found, creating it right now"
        k create namespace flux
    fi
}

service_exists() {
    local service_name="$1"
    kube_resource_exists "service/$service_name"
}

pod_exists() {
    local pod_name="$1"
    kube_resource_exists "pod/$pod_name"
}

kill_pod_silently() {
    local namespace="$1"
    local podname="$2"
    k delete --force --grace-period=0 -n "$namespace" "pod/$podname" --ignore-not-found=true
}


