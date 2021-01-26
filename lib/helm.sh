#!/usr/bin/env bash

if type dep &>/dev/null ; then
    dep include log2/shell-common log
else
    include log2/shell-common lib/log.sh
fi

req helm jq yq

chart_check(){
    usage()
    {
        COLUMNS=$(tput cols) 
        title="Analyse Helm chart to check for anomalies" 
        printf "%*s\n" $(( ( ${#title} + COLUMNS ) / 2 )) "$title"
        log ""
        log "DESCRIPTION:"
        log "simple script to check quality of Helm chart with respect to current release"
        log ""
        log "OPTIONS:"
        log "  $(b -s) | $(b --show)"
        log "      show chart content (uses $(i helm template))"
        log "  $(b -d) | $(b --debug)"
        log "      use debug option with helm"
        log "  $(b -h) | $(b --help)"
        log "      show this help"
        log ""
    }


    SHOW_CONTENT=
    DEBUG=

    for i in "$@"
    do
        case $i in
            -s | --show)
                SHOW_CONTENT=true
                shift
                ;;	
            -d | --debug)
                DEBUG=true
                shift
                ;;
            -h | --help )           
                usage
                exit
                ;;
            # * ) 
            #     usage
            #     exit 1
        esac
    done

    valuesFile=$1
    targetDir=$2

    isDeployed() {
        helm get values --namespace "$NAMESPACE" "$RELEASE_NAME" >/dev/null 2>&1
    }

    getVersion() {
        helm get values -o json --namespace "$NAMESPACE" "$RELEASE_NAME" | jq ".$1.deployment.image.tag" -r
    }

    emit() {
        local params=("$@")
        printf "%b" "${params[@]}"
    }

    values() {
        if [[ -n $(yq e '.kind // ""' "$valuesFile") ]] ; then
            yq e '.spec.values' "$valuesFile"
        else
            cat "$valuesFile"
        fi
    }

    if [ -n "$DEBUG" ]; then
        EXTRA_HELM_OPTIONS="--debug"
    fi 

    REQS=$targetDir/requirements.yaml
    if [[ -f $REQS ]] ; then
        start_log_line "Checking charts $(b "$targetDir") depends upon (old style)"
        emit " ... found $(b "$(yq e '.dependencies | length' "$REQS")") dependencies"
        for I in $(yq e '.dependencies[] | path | .[-1]' "$REQS") ; do
            DEP=$(yq e .dependencies\["$I"\].name "$REQS" )
            VER=$(yq e .dependencies\["$I"\].version "$REQS" )
            emit " ... checking $(b "$DEP") $(b "$VER")"
            TGZ="$targetDir/charts/$DEP-$VER.tgz"
            if [ -s "$TGZ" ]; then
                end_log_line "(OK)"
            else
                end_log_line_err " FAIL!"
                warn "Could not find archive for $(b "$DEP") $(b "$VER"), i.e., file $(b "$TGZ")." >&2 
                whine "Please provide it by running $(b helm dep update "$targetDir") and re-run this script"
            fi
        done
        end_log_line " everything looks fine!"
    fi
    CHART=$targetDir/Chart.yaml
    if (( $(yq e '.dependencies | length' "$CHART") > 0 )); then
        start_log_line "Checking charts $(b "$targetDir") depends upon (new style)"
        emit " ... found $(b "$(yq e '.dependencies | length' "$CHART")") dependencies"
        for I in $(yq e '.dependencies[] | path | .[-1]' "$CHART") ; do
            DEP=$(yq e .dependencies\["$I"\].name "$CHART" )
            VER=$(yq e .dependencies\["$I"\].version "$CHART" )
            emit " ... checking $(b "$DEP") $(b "$VER")"
            TGZ="$targetDir/charts/$DEP-$VER.tgz"
            if [ -s "$TGZ" ]; then
                end_log_line "(OK)"
            else
                end_log_line_err " FAIL!"
                warn "Could not find archive for $(b "$DEP") $(b "$VER"), i.e., file $(b "$TGZ")." >&2 
                whine "Please provide it by running $(b helm dep update "$targetDir") and re-run this script"
            fi
        done
        end_log_line " everything looks fine!"
    fi


    start_log_line "Checking helm chart $(b "$targetDir") ..."
    if helm lint "$targetDir" --values <(values); then
        end_log_line " chart is fine"
    else
        whine "Could not use chart $(b "$targetDir"), helm found it to be bad"
    fi

    if [ -n "$SHOW_CONTENT" ]; then
        log "Showing chart content as requested"
        helm template "$targetDir" $EXTRA_HELM_OPTIONS --values <(values)
    fi
}

helm_repo_add() {
    local repo_name="$1"
    local repo_url="$2"
    log "Checking helm repository $(b "$repo_name") - URL: $(b "$repo_url")"
    if helm repo add "$repo_name" "$repo_url" --no-update 2>/dev/null ; then
        log "Repository $(b "$repo_name") added just now, performing update"
        helm repo update
        log "Completed update of $(b "$repo_name") from URL $(b "$repo_url")"
    else
        log "Repository $(b "$repo_name") was already present, nothing to update"
    fi
}

prepare_helm_plugin() {
    local plugin_name="$1"
    local plugin_url="$2"
    if helm plugin install "$plugin_url" 2>/dev/null ; then
        log "Installed $(b "${plugin_name}" plugin)"
    else
        log "$(b "${plugin_name}" plugin) appears to be already installed, nothing to do"
    fi
}

h() {
    local params=("$@")
    helm --namespace "$NAMESPACE" "${params[@]}"
}

