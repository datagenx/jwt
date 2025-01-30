#!/usr/bin/env bash
set -eu -o pipefail

reportDir="test-reports"

# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_test="Run the Go tests"
test() {
    mkdir -p "${reportDir}"
    # -count=1 is used to forcibly disable test result caching
    ./bin/gotestsum --junitfile="${reportDir}/junit.xml" -- -race -count=1 "${@:-./...}"
}

# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_run_goimports="Run goimports for package"
# shellcheck disable=SC2120
run-goimports () {
    if [ ! -f ./bin/gosimports ]; then
        install-devtools
    fi
  ./bin/gosimports -local "github.com/circleci/server/tests/system_tests" -w "${@:-.}"
}

help_lint="Run golanci-lint to lint go files."
lint() {
    ./bin/golangci-lint run "${@:-./...}"
    if [ -n "$(run-goimports)" ]; then
        echo "Go imports check failed, please run ./do goimports"
        exit 1
    fi
}

help_go_mod_tidy="Run 'go mod tidy' to clean up module files."
go-mod-tidy() {
    go mod tidy -v
}

help_install_devtools="Install tools that other tasks expect into ./bin"
install-devtools() {
    local tools=()
    while IFS='' read -r value; do
        tools+=("$value")
    done < <(grep _ tools/tools.go | awk -F'"' '{print $2}')

    install-go-bin "${tools[@]}"
}

install-go-bin() {
    local binDir="$PWD/bin"
    for pkg in "${@}"; do
        echo "${pkg}"
        (
          cd tools
          GOBIN="${binDir}" go install "${pkg}"
        )
    done
}

help-text-intro() {
    echo "
DO

A set of simple repetitive tasks that adds minimally
to standard tools used to build and test the build_agent.
(e.g. go and docker)
"
}

### START FRAMEWORK ###
# Do Version 0.0.4
# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_self_update="Update the framework from a file.

Usage: $0 self-update FILENAME
"
self-update() {
    local source selfpath pattern
    source="$1"
    selfpath="${BASH_SOURCE[0]}"
    cp "$selfpath" "$selfpath.bak"
    pattern='/### START FRAMEWORK/,/END FRAMEWORK ###$/'
    (sed "${pattern}d" "$selfpath"; sed -n "${pattern}p" "$source") \
        > "$selfpath.new"
    mv "$selfpath.new" "$selfpath"
    chmod --reference="$selfpath.bak" "$selfpath"
}

# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_completion="Print shell completion function for this script.

Usage: $0 completion SHELL"
completion() {
    local shell
    shell="${1-}"

    if [ -z "$shell" ]; then
      echo "Usage: $0 completion SHELL" 1>&2
      exit 1
    fi

    case "$shell" in
      bash)
        (echo
        echo '_dotslashdo_completions() { '
        # shellcheck disable=SC2016
        echo '  COMPREPLY=($(compgen -W "$('"$0"' list)" "${COMP_WORDS[1]}"))'
        echo '}'
        echo 'complete -F _dotslashdo_completions '"$0"
        );;
      zsh)
cat <<EOF
_dotslashdo_completions() {
  local -a subcmds
  subcmds=()
  DO_HELP_SKIP_INTRO=1 $0 help | while read line; do
EOF
cat <<'EOF'
    cmd=$(cut -f1  <<< $line)
    cmd=$(awk '{$1=$1};1' <<< $cmd)

    desc=$(cut -f2- <<< $line)
    desc=$(awk '{$1=$1};1' <<< $desc)

    subcmds+=("$cmd:$desc")
  done
  _describe 'do' subcmds
}

compdef _dotslashdo_completions do
EOF
        ;;
     fish)
cat <<EOF
complete -e -c do
complete -f -c do
for line in (string split \n (DO_HELP_SKIP_INTRO=1 $0 help))
EOF
cat <<'EOF'
  set cmd (string split \t $line)
  complete -c do  -a $cmd[1] -d $cmd[2]
end
EOF
    ;;
    esac
}

list() {
    declare -F | awk '{print $3}'
}

# This variable is used, but shellcheck can't tell.
# shellcheck disable=SC2034
help_help="Print help text, or detailed help for a task."
help() {
    local item
    item="${1-}"
    if [ -n "${item}" ]; then
      local help_name
      help_name="help_${item//-/_}"
      echo "${!help_name-}"
      return
    fi

    if [ -z "${DO_HELP_SKIP_INTRO-}" ]; then
      type -t help-text-intro > /dev/null && help-text-intro
    fi
    for item in $(list); do
      local help_name text
      help_name="help_${item//-/_}"
      text="${!help_name-}"
      [ -n "$text" ] && printf "%-30s\t%s\n" "$item" "$(echo "$text" | head -1)"
    done
}

case "${1-}" in
  list) list;;
  ""|"help") help "${2-}";;
  *)
    if ! declare -F "${1}" > /dev/null; then
        printf "Unknown target: %s\n\n" "${1}"
        help
        exit 1
    else
        "$@"
    fi
  ;;
esac
### END FRAMEWORK ###
