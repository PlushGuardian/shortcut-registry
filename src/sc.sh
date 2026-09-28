# shellcheck shell=bash
# --- sc: shortcut registry ---
#   Code lives here: $SHORTCUT_REGISTRY_PATH/sc.sh
#   Data lives here: $SHORTCUT_REGISTRY_PATH/shortcuts (TSV: name\tdesc\tcmd)
#
#   sc add NAME "DESCRIPTION" :: 'COMMAND'   add a shortcut (quote the command)
#   sc NAME [args...]                        run a shortcut
#   sc list                                  list names + descriptions
#   sc help                                  help + current commands
#   sc rm NAME [NAME ...]                    remove one or more shortcuts
#
#   Variables in commands:
#     - positional placeholders {1} {2} ... stand for whole arguments:
#         sc add ytdl "Download YT" :: 'yt-dlp --cookies-from-browser firefox {1}'
#         sc ytdl <url>
#     - shell variables are expanded at run time (single-quote the command when adding):
#         sc add m3 "Extract mp3" :: 'yt-dlp -x --audio-format mp3 "$FMT" {1}'
#         FMT=bestaudio sc m3 <url>
#     - extra arguments beyond the used placeholders are appended at the end.
#
# Base directory (only configurable thing; set/export before sourcing to override):
: "${SHORTCUT_REGISTRY_PATH:=$HOME/.shortcut-registry}"
# Hardcoded file names based on the base directory:
SC_FILE="$SHORTCUT_REGISTRY_PATH/shortcuts"
[[ -d "$SHORTCUT_REGISTRY_PATH" ]] || mkdir -p "$SHORTCUT_REGISTRY_PATH"

sc() {
    case "${1:-list}" in
        add)
            if [[ "$*" != *' :: '* ]]; then
                echo "usage: sc add NAME DESCRIPTION :: 'COMMAND'" >&2
                return 1
            fi
            local name="$2" rest="${*:3}" desc cmd
            desc="${rest%% ::*}"
            cmd="${rest#*:: }"
            if [[ -f "$SC_FILE" ]] && awk -F'\t' -v n="$name" \
                '$1==n {found=1; exit} END {exit !found}' "$SC_FILE"; then
                echo "sc: shortcut '$name' already exists (remove it first: sc rm $name)" >&2
                return 1
            fi
            printf '%s\t%s\t%s\n' "$name" "$desc" "$cmd" >> "$SC_FILE"
            ;;
        rm)
            if (( $# < 2 )); then
                echo "usage: sc rm NAME [NAME ...]" >&2
                return 1
            fi
            if [[ ! -f "$SC_FILE" ]]; then
                echo "sc: no shortcuts to remove" >&2
                return 1
            fi
            local all="${*:2}" name removed="" missing=""
            # separate requested names into existing / not-found
            for name in $all; do
                if awk -F'\t' -v n="$name" '$1==n {found=1} END {exit !found}' "$SC_FILE"; then
                    removed+="$name "
                else
                    missing+="$name "
                fi
            done
            if [[ -n "$removed" ]]; then
                awk -F'\t' -v s="$removed" '
                    BEGIN { n = split(s, a, " "); for (i = 1; i <= n; i++) del[a[i]] = 1 }
                    !($1 in del)
                ' "$SC_FILE" > "$SC_FILE.tmp" && mv "$SC_FILE.tmp" "$SC_FILE"
                for name in $removed; do
                    echo "Removed shortcut '$name'"
                done
            fi
            for name in $missing; do
                echo "No shortcut '$name' (nothing removed)" >&2
            done
            ;;
        list|ls|-l)
            if [[ ! -f "$SC_FILE" ]]; then
                echo "No shortcuts yet. Add with: sc add name desc :: command"
                return 0
            fi
            local width colw avail name desc n chunks i
            width=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
            (( width = width > 40 ? width : 80 ))
            # size the name column to the longest name
            colw=0
            while IFS=$'\t' read -r n _; do
                (( ${#n} > colw )) && colw=${#n}
            done < "$SC_FILE"
            (( colw = colw + 2 ))
            (( avail = width - colw - 1 ))
            (( avail < 20 )) && avail=20
            while IFS=$'\t' read -r name desc _; do
                if (( ${#desc} <= avail )); then
                    printf '%-*s %s\n' "$colw" "$name" "$desc"
                else
                    # wrap long descriptions; continuation lines align under the description
                    mapfile -t chunks < <(printf '%s\n' "$desc" | fold -s -w "$avail")
                    printf '%-*s %s\n' "$colw" "$name" "${chunks[0]}"
                    for ((i = 1; i < ${#chunks[@]}; i++)); do
                        printf '%*s %s\n' "$colw" "" "${chunks[i]}"
                    done
                fi

            done < "$SC_FILE"
            ;;
        help|-h|--help)
            cat <<'EOF'
sc — shortcut registry
  sc add NAME "DESCRIPTION" :: 'COMMAND'   add a shortcut
  sc NAME [args...]                        run a shortcut
  sc list                                  list names + descriptions
  sc help                                  this help + current commands
  sc rm NAME [NAME ...]                  remove one or more shortcuts
Placeholders {1}..{9} stand for whole arguments; leftover args are appended.
Shortcut names are unique; Tab completes subcommands and names.
EOF
            echo
            echo "Current shortcuts:"
            if [[ -f "$SC_FILE" ]]; then
                awk -F'\t' '{printf "  %-12s %s\n    %s\n", $1, $2, $3}' "$SC_FILE"
            else
                echo "  (none yet)"
            fi
            ;;
        *)
            if [[ ! -f "$SC_FILE" ]]; then
                echo "No shortcuts yet." >&2; return 1
            fi
            local line cmd rest q maxN i
            line=$(awk -F'\t' -v n="$1" '$1==n {print; exit}' "$SC_FILE")
            if [[ -z "$line" ]]; then echo "No shortcut '$1'" >&2; return 1; fi
            cmd=$(printf '%s\n' "$line" | cut -f3-)
            shift
            rest=("$@")

            if [[ "$cmd" == *'{'* ]]; then
                maxN=0
                for ((i = 1; i <= 9; i++)); do
                    [[ "$cmd" == *"{$i}"* ]] && maxN=$i
                done
                for ((i = 1; i <= maxN; i++)); do
                    if (( i <= ${#rest[@]} )); then
                        q=$(printf '%q' "${rest[$((i - 1))]}")
                    else
                        q="''"
                    fi
                    cmd=${cmd//"{$i}"/$q}
                done
                for ((i = maxN; i < ${#rest[@]}; i++)); do
                    q=$(printf '%q' "${rest[$i]}")
                    cmd+=" $q"
                done
            else
                local arg
                for arg in "${rest[@]}"; do
                    q=$(printf '%q' "$arg")
                    cmd+=" $q"
                done
            fi
            eval "$cmd"
            ;;
    esac
}

# Tab completion for sc (subcommands + registered shortcut names)
_sc_complete() {
    local cur prev n
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    local names=()
    if [[ -f "$SC_FILE" ]]; then
        while IFS=$'\t' read -r n _; do
            [[ -n "$n" ]] && names+=("$n")
        done < "$SC_FILE"
    fi
    if [[ "$prev" == rm ]]; then
        COMPREPLY=( $(compgen -W "${names[*]}" -- "$cur") )
    elif (( COMP_CWORD == 1 )); then
        COMPREPLY=( $(compgen -W "add rm list ls help --help ${names[*]}" -- "$cur") )
    fi
}
if command -v complete >/dev/null 2>&1; then
    complete -F _sc_complete sc
fi
