# User-defined shell functions sourced from ~/.zshrc
# Keep functions here to reduce .zshrc clutter.

# lower-case string (zsh builtin, no external deps)
function lower() {
    echo ${(L)@}
}

# yaml to json (requires: yq)
# Usage: cat file.yaml | y2j
function y2j() {
    yq -o=json
}

# json to yaml (requires: yq)
# Usage: cat file.json | j2y
function j2y() {
    yq -P
}

# URL decode (requires: python3)
function urldecode() {
    python3 -c 'import sys; from urllib.parse import unquote; print(unquote(sys.argv[1]))' "$@"
}

# Convert a human-readable timestamp to epoch seconds / milliseconds
# Uses gdate (macOS via `brew install coreutils`) or date (Linux)
# Usage: epoch "2024-01-15 10:30:00"
#        epoch "2024-01-15 10:30:00" ms
function epoch() {
    local datecmd=date
    command -v gdate &>/dev/null && datecmd=gdate

    if [[ "$#" -eq 1 ]]; then
        $datecmd -d "$1" +%s
        return
    fi

    # Note: zsh doesn't recognize -a and -o as logical AND and OR.
    # See https://zsh.sourceforge.io/Doc/Release/Conditional-Expressions.html
    if [[ "$#" -eq 2 && $2 == 'ms' ]]; then
        echo $(($($datecmd -d "$1" +%s%N) / 1000000))
    fi
}
