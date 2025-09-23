# Handy utility functions.

# String length in number of characters
# Need to check if the current locale supports multi-byte chars or not
function slen()
{
    echo -n "$@" | wc -m | sed -e 's/^[ \t]*//'
}
