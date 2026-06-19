# Optional compatibility aliases for the old hacker-themed command names.
# Source this file manually after Marvin if a local shell still depends on them.

haxstatus() { marvin status "$@"; }
haxweather() { marvin weather "$@"; }
haxforecast() { marvin forecast "$@"; }
haxoff() { touch "$HOME/.marvinquiet"; export MARVIN_QUIET=1; }
haxon() { rm -f "$HOME/.marvinquiet"; unset MARVIN_QUIET; }
haxdoctor() { marvin doctor "$@"; }
