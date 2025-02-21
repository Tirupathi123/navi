#!/usr/bin/env bash

ARG_REGEX="<[0-9a-zA-Z_]+>"
ARG_DELIMITER="£"

arg::dict() {
   local -r fn="$(awk -F'---' '{print $1}')"
   local -r opts="$(awk -F'---' '{print $2}')"

   dict::new fn "$fn" opts "$opts"
}

arg::interpolate() {
   local -r arg="$1"
   local -r value="$2"

   sed "s|<${arg}>|\"${value}\"|g"
}

arg::next() {
   grep -Eo "$ARG_REGEX" \
      | xargs \
      | head -n1 \
      | tr -d '<' \
      | tr -d '>'
}

arg::deserialize() {
   local -r arg="$1"

   if [ ${arg:0:1} = "'" ]; then
      local -r out="$(echo "${arg:1:${#arg}-2}")"
   else
      local -r out="$arg"
   fi

   echo "$out" | sed "s/${ARG_DELIMITER}/ /g"
}

# TODO: separation of concerns
arg::pick() {
   local -r arg="$1"
   local -r cheat="$2"

   local -r prefix="$ ${arg}:"
   local -r length="$(echo "$prefix" | str::length)"
   local -r arg_dict="$(grep "$prefix" "$cheat" | str::sub $((length + 1)) | arg::dict)"

   local -r fn="$(dict::get "$arg_dict" fn)"
   local -r args_str="$(dict::get "$arg_dict" opts | tr ' ' '\n' || echo "")"
   local arg_name=""

   for arg_str in $args_str; do
      if [ -z $arg_name ]; then
         arg_name="$(echo "$arg_str" | str::sub 2)"
      else
         eval "local $arg_name"='$arg_str'
         arg_name=""
      fi
   done

   if [ -n "$fn" ]; then
      local suggestions="$(eval "$fn" 2>/dev/null)"
      if [ -n "$suggestions" ]; then
         echo "$suggestions" | ui::pick --prompt "$arg: " --header-lines "${headers:-0}" | str::column "${column:-}"
      fi
   elif ${NAVI_FZF_ALL_INPUTS:-false}; then
      echo "" | ui::pick --prompt "$arg: " --print-query --height 1
   else
      printf "\033[0;36m${arg}:\033[0;0m " > /dev/tty
      read -r value
      ui::clear_previous_line > /dev/tty
      printf "$value"
   fi
}
