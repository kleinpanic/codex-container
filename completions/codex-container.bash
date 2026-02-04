# bash completion for codex-container

_codex_container() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local opts="-w --workspace -c --config -n --name -e --env --env-file --agent-docker --agent-image --agent-shell --agent-workspace --agent-config --agent-ssh-auth-sock --agent-env --agent-env-file --agent-root --host-codex-dir --allow-sudo --allow-docker --persist-ssh --seed-known-hosts --ephemeral --session --auto-cleanup --label --recreate --last --debug --dry-run --yes --all --force --include-self -h --help --version"
    local subs="start stop rm status doctor shell exec logs agent ps clean prune-images"

    case "$prev" in
        -w|--workspace|-c|--config|-n|--name|--env-file|--agent-image|--agent-workspace|--agent-config|--agent-env-file|--seed-known-hosts|--label)
            return
            ;;
        -e|--env|--agent-env)
            return
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
        return
    fi

    COMPREPLY=( $(compgen -W "$subs" -- "$cur") )
}

complete -F _codex_container codex-container
