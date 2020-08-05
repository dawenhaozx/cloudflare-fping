#!/usr/bin/env bash

set -euo pipefail

# based on https://raw.githubusercontent.com/tanhauhau/Inquirer.sh/master/dist/inquirer.sh
arrow="$(echo -e '\xe2\x9d\xaf')"
checked="$(echo -e '\xe2\x97\x89')"
unchecked="$(echo -e '\xe2\x97\xaf')"

red="$(tput setaf 1)"
green="$(tput setaf 2)"
cyan="$(tput setaf 6)"
bold="$(tput bold)"
normal="$(tput sgr0)"
dim=$'\e[2m'

print() {
  echo "$1"
  tput el
}

join() {
  local IFS=$'\n'
  local var=("$1"[@])
  local _join_list=("${!var}")
  local first=true
  for item in "${_join_list[@]}"; do
    if [ "$first" = true ]; then
      printf "%s" "$item"
      first=false
    else
      printf "${2-, }%s" "$item"
    fi
  done
}

gen_env_from_options() {
  local IFS=$'\n'
  local var=("$1"[@])
  local _indices=("${!var}")
  var=("$2"[@])
  local _env_names=("${!var}")
  local _checkbox_selected

  for i in $(gen_index ${#_env_names[@]}); do
    _checkbox_selected[i]=false
  done

  for i in "${_indices[@]}"; do
    _checkbox_selected[i]=true
  done

  for i in $(gen_index ${#_env_names[@]}); do
    printf "%s=%s\n" "${_env_names[i]}" "${_checkbox_selected[i]}"
  done
}

on_default() {
  true;
}

on_keypress() {
  local OLD_IFS=$IFS
  local key
  local on_up=${1:-on_default}
  local on_down=${2:-on_default}
  local on_space=${3:-on_default}
  local on_enter=${4:-on_default}
  local on_left=${5:-on_default}
  local on_right=${6:-on_default}
  local on_ascii=${7:-on_default}
  local on_backspace=${8:-on_default}
  _break_keypress=false
  while IFS="" read -rsn1 key; do
      case "$key" in
      $'\x1b')
          read -rsn1 key
          if [[ "$key" == "[" ]]; then
              read -rsn1 key
              case "$key" in
              'A') $on_up;;
              'B') $on_down;;
              'D') $on_left;;
              'C') $on_right;;
              esac
          fi
          ;;
      ' ') $on_space ' ';;
      [a-z0-9A-Z\!\#\$\&\+\,\-\.\/\;\=\?\@\[\]\^\_\{\}\~]) $on_ascii $key;;
      $'\x7f') $on_backspace $key;;
      '') $on_enter $key;;
      esac
      if [ $_break_keypress = true ]; then
        break
      fi
  done
  IFS=$OLD_IFS
}

gen_index() {
  local k=$1
  local l=0
  for((l=0;l<k;l++));
  do
    echo $l
  done
}

cleanup() {
  # Reset character attributes, make cursor visible, and restore
  # previous screen contents (if possible).
  tput sgr0
  tput cnorm
  stty echo
}

control_c() {
  cleanup
  exit $?
}

select_indices() {
  local var=("$1"[@])
  local _select_list <<< "${!var}"
  var=("$2"[@])
  local _select_indices <<< "${!var}"
  local _select_var_name=$3
  declare -a new_array
  for i in $(gen_index ${#_select_indices[@]}); do
    new_array+=("${_select_list[${_select_indices[i]}]}")
  done
  read -r -a ${_select_var_name?} <<< "${new_array[@]}"
  unset new_array
}

on_checkbox_input_up() {
  remove_checkbox_instructions
  tput cub "$(tput cols)"

  if [ "${_checkbox_selected[$_current_index]}" = true ]; then
    printf '%s' " ${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
  else
    printf '%s' " ${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
  fi
  tput el

  if [ $_current_index = 0 ]; then
    _current_index=$((${#_checkbox_list[@]}-1))
    tput cud $((${#_checkbox_list[@]}-1))
    tput cub "$(tput cols)"
  else
    _current_index=$((_current_index-1))

    tput cuu1
    tput cub "$(tput cols)"
    tput el
  fi

  if [ "${_checkbox_selected[$_current_index]}" = true ]; then
    printf '%s' "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
  else
    printf '%s' "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
  fi
}

on_checkbox_input_down() {
  remove_checkbox_instructions
  tput cub "$(tput cols)"

  if [ "${_checkbox_selected[$_current_index]}" = true ]; then
    printf '%s' " ${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
  else
    printf '%s' " ${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
  fi

  tput el

  if [ $_current_index = $((${#_checkbox_list[@]}-1)) ]; then
    _current_index=0
    tput cuu $((${#_checkbox_list[@]}-1))
    tput cub "$(tput cols)"
  else
    _current_index=$((_current_index+1))
    tput cud1
    tput cub "$(tput cols)"
    tput el
  fi

  if [ "${_checkbox_selected[$_current_index]}" = true ]; then
    printf '%s' "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
  else
    printf '%s' "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
  fi
}

on_checkbox_input_enter() {
  local OLD_IFS=$IFS
  _checkbox_selected_indices=()
  _checkbox_selected_options=()
  IFS=$'\n'

  for i in $(gen_index ${#_checkbox_list[@]}); do
    if [ "${_checkbox_selected[i]}" = true ]; then
      _checkbox_selected_indices+=("$i")
      _checkbox_selected_options+=("${_checkbox_list[i]}")
    fi
  done

  tput cud $((${#_checkbox_list[@]}-_current_index))
  tput cub "$(tput cols)"

  for i in $(seq $((${#_checkbox_list[@]}+1))); do
    tput el1
    tput el
    tput cuu1
  done
  tput cub "$(tput cols)"

  tput cuf $((${#prompt}+3))
  printf '%s' "${cyan}$(join _checkbox_selected_options)${normal}"
  tput el

  tput cud1
  tput cub "$(tput cols)"
  tput el

  _break_keypress=true
  IFS=$OLD_IFS
}

on_checkbox_input_space() {
  remove_checkbox_instructions
  tput cub "$(tput cols)"
  tput el
  if [ "${_checkbox_selected[$_current_index]}" = true ]; then
    _checkbox_selected[$_current_index]=false
  else
    _checkbox_selected[$_current_index]=true
  fi

  if [ "${_checkbox_selected[$_current_index]}" = true ]; then
    printf '%s' "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[$_current_index]} ${normal}"
  else
    printf '%s' "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[$_current_index]} ${normal}"
  fi
}

remove_checkbox_instructions() {
  if [ $_first_keystroke = true ]; then
    tput cuu $((_current_index+1))
    tput cub "$(tput cols)"
    tput cuf $((${#prompt}+3))
    tput el
    tput cud $((_current_index+1))
    _first_keystroke=false
  fi
}

# for vim movements
on_checkbox_input_ascii() {
  local key=$1
  case $key in
    "j" ) on_checkbox_input_down;;
    "k" ) on_checkbox_input_up;;
  esac
}

_checkbox_input() {
  local i
  local j
  prompt=$1
  local var=("$2"[@])
  _checkbox_list=("${!var}")
  _current_index=0
  _first_keystroke=true

  trap control_c SIGINT EXIT

  stty -echo
  tput civis

  print "${normal}${green}?${normal} ${bold}${prompt}${normal} ${dim}(Press <space> to select, <enter> to finalize)${normal}"

  for i in $(gen_index ${#_checkbox_list[@]}); do
    _checkbox_selected[i]=false
  done

  if [ -n "$3" ]; then
    var=("$3"[@])
    _selected_indices=("${!var}")
    for i in "${_selected_indices[@]}"; do
      _checkbox_selected[i]=true
    done
  fi

  for i in $(gen_index ${#_checkbox_list[@]}); do
    tput cub "$(tput cols)"
    if [ $i = 0 ]; then
      if [ "${_checkbox_selected[i]}" = true ]; then
        print "${cyan}${arrow}${green}${checked}${normal} ${_checkbox_list[i]} ${normal}"
      else
        print "${cyan}${arrow}${normal}${unchecked} ${_checkbox_list[i]} ${normal}"
      fi
    else
      if [ "${_checkbox_selected[i]}" = true ]; then
        print " ${green}${checked}${normal} ${_checkbox_list[i]} ${normal}"
      else
        print " ${unchecked} ${_checkbox_list[i]} ${normal}"
      fi
    fi
    tput el
  done

  for j in $(gen_index ${#_checkbox_list[@]}); do
    tput cuu1
  done

  on_keypress on_checkbox_input_up on_checkbox_input_down on_checkbox_input_space on_checkbox_input_enter on_default on_default on_checkbox_input_ascii
}

checkbox_input() {
  _checkbox_input "$1" "$2"
  _checkbox_input_output_var_name=$3
  select_indices _checkbox_list _checkbox_selected_indices $_checkbox_input_output_var_name

  unset _checkbox_list
  unset _break_keypress
  unset _first_keystroke
  unset _current_index
  unset _checkbox_input_output_var_name
  unset _checkbox_selected_indices
  unset _checkbox_selected_options

  cleanup
}

checkbox_input_indices() {
  _checkbox_input "$1" "$2" "$3"
  _checkbox_input_output_var_name=$3

  declare -a new_array
  for i in $(gen_index ${#_checkbox_selected_indices[@]}); do
    new_array+=("${_checkbox_selected_indices[i]}")
  done
  read -r -a ${_checkbox_input_output_var_name?} <<< "${new_array[@]}"
  unset new_array

  unset _checkbox_list
  unset _break_keypress
  unset _first_keystroke
  unset _current_index
  unset _checkbox_input_output_var_name
  unset _checkbox_selected_indices
  unset _checkbox_selected_options

  cleanup
}

on_list_input_up() {
  remove_list_instructions
  tput cub "$(tput cols)"

  printf '%s' "  ${_list_options[$_list_selected_index]}"
  tput el

  if [ $_list_selected_index = 0 ]; then
    _list_selected_index=$((${#_list_options[@]}-1))
    tput cud $((${#_list_options[@]}-1))
    tput cub "$(tput cols)"
  else
    _list_selected_index=$((_list_selected_index-1))

    tput cuu1
    tput cub "$(tput cols)"
    tput el
  fi

  printf "${cyan}${arrow} %s ${normal}" "${_list_options[$_list_selected_index]}"
}

on_list_input_down() {
  remove_list_instructions
  tput cub "$(tput cols)"

  printf '%s' "  ${_list_options[$_list_selected_index]}"
  tput el

  if [ $_list_selected_index = $((${#_list_options[@]}-1)) ]; then
    _list_selected_index=0
    tput cuu $((${#_list_options[@]}-1))
    tput cub "$(tput cols)"
  else
    _list_selected_index=$((_list_selected_index+1))
    tput cud1
    tput cub "$(tput cols)"
    tput el
  fi
  printf "${cyan}${arrow} %s ${normal}" "${_list_options[$_list_selected_index]}"
}

on_list_input_enter_space() {
  local OLD_IFS=$IFS
  IFS=$'\n'

  tput cud $((${#_list_options[@]}-_list_selected_index))
  tput cub "$(tput cols)"

  for i in $(seq $((${#_list_options[@]}+1))); do
    tput el1
    tput el
    tput cuu1
  done
  tput cub "$(tput cols)"

  tput cuf $((${#prompt}+3))
  printf '%s' "${cyan}${_list_options[$_list_selected_index]}${normal}"
  tput el

  tput cud1
  tput cub "$(tput cols)"
  tput el

  _break_keypress=true
  IFS=$OLD_IFS
}

remove_list_instructions() {
  if [ $_first_keystroke = true ]; then
    tput cuu $((_list_selected_index+1))
    tput cub "$(tput cols)"
    tput cuf $((${#prompt}+3))
    tput el
    tput cud $((_list_selected_index+1))
    _first_keystroke=false
  fi
}

_list_input() {
  local i
  local j
  local var=("$2"[@])
  prompt=$1
  _list_options=("${!var}")

  _list_selected_index=0
  _first_keystroke=true

  trap control_c SIGINT EXIT

  stty -echo
  tput civis

  print "${normal}${green}?${normal} ${bold}${prompt}${normal} ${dim}(Use arrow keys)${normal}"

  for i in $(gen_index ${#_list_options[@]}); do
    tput cub "$(tput cols)"
    if [ $i = 0 ]; then
      print "${cyan}${arrow} ${_list_options[i]} ${normal}"
    else
      print "  ${_list_options[i]}"
    fi
    tput el
  done

  for j in $(gen_index ${#_list_options[@]}); do
    tput cuu1
  done

  on_keypress on_list_input_up on_list_input_down on_list_input_enter_space on_list_input_enter_space

}

list_input() {
  _list_input "$1" "$2"
  local var_name=$3
  read -r ${var_name?} <<< "${_list_options[$_list_selected_index]}"
  unset _list_selected_index
  unset _list_options
  unset _break_keypress
  unset _first_keystroke

  cleanup
}

list_input_index() {
  _list_input "$1" "$2"
  local var_name=$3
  read -r ${var_name?} <<< "$_list_selected_index"
  unset _list_selected_index
  unset _list_options
  unset _break_keypress
  unset _first_keystroke

  cleanup
}

on_text_input_left() {
  remove_regex_failed
  if [ $_current_pos -gt 0 ]; then
    tput cub1
    _current_pos=$((_current_pos-1))
  fi
}

on_text_input_right() {
  remove_regex_failed
  if [ $_current_pos -lt ${#_text_input} ]; then
    tput cuf1
    _current_pos=$((_current_pos+1))
  fi
}

on_text_input_enter() {
  remove_regex_failed

  if [[ "$_text_input" =~ $_text_input_regex && "$($_text_input_validator "$_text_input")" = true ]]; then
    tput cub "$(tput cols)"
    tput cuf $((${#_read_prompt}-19))
    printf '%s' "${cyan}${_text_input}${normal}"
    tput el
    tput cud1
    tput cub "$(tput cols)"
    tput el
    read -r ${var_name?} <<< "$_text_input"
    _break_keypress=true
  else
    _text_input_regex_failed=true
    tput civis
    tput cud1
    tput cub "$(tput cols)"
    tput el
    printf '%s>>%s %s' "${red}" "${normal}" "$_text_input_regex_failed_msg"
    tput cuu1
    tput cub "$(tput cols)"
    tput cuf $((${#_read_prompt}-19))
    tput el
    _text_input=""
    _current_pos=0
    tput cnorm
  fi
}

on_text_input_ascii() {
  remove_regex_failed
  local c=$1

  if [ "$c" = '' ]; then
    c=' '
  fi

  local rest="${_text_input:$_current_pos}"
  _text_input="${_text_input:0:$_current_pos}$c$rest"
  _current_pos=$((_current_pos+1))

  tput civis
  printf '%s' "$c$rest"
  tput el
  if [ ${#rest} -gt 0 ]; then
    tput cub ${#rest}
  fi
  tput cnorm
}

on_text_input_backspace() {
  remove_regex_failed
  if [ $_current_pos -gt 0 ]; then
    local start="${_text_input:0:$((_current_pos-1))}"
    local rest="${_text_input:$_current_pos}"
    _current_pos=$((_current_pos-1))
    tput cub 1
    tput el
    tput sc
    printf '%s' "$rest"
    tput rc
    _text_input="$start$rest"
  fi
}

remove_regex_failed() {
  if [ $_text_input_regex_failed = true ]; then
    _text_input_regex_failed=false
    tput sc
    tput cud1
    tput el1
    tput el
    tput rc
  fi
}

text_input_default_validator() {
  echo true;
}

text_input() {
  local prompt=$1
  local var_name=$2
  local _text_input_regex="${3:-"\.+"}"
  local _text_input_regex_failed_msg=${4:-"Input validation failed"}
  local _text_input_validator=${5:-text_input_default_validator}
  local _read_prompt_start=$'\e[32m?\e[39m\e[1m'
  local _read_prompt_end=$'\e[22m'
  local _read_prompt
  _read_prompt=$($_read_prompt_start ${prompt} $_read_prompt_end)
  local _current_pos=0
  local _text_input_regex_failed=false
  local _text_input=""
  printf '%s' "$_read_prompt"

  trap control_c SIGINT EXIT

  stty -echo
  tput cnorm

  on_keypress on_default on_default on_text_input_ascii on_text_input_enter on_text_input_left on_text_input_right on_text_input_ascii on_text_input_backspace
  read -r ${var_name?} <<< "$_text_input"

  cleanup
}

# based on https://raw.githubusercontent.com/kahkhang/ora.sh/master/ora.sh
spinner() {
  local i=1 delay=0.05 FUNCTION_NAME="$2" list tempfile
  local green cyan normal
  green=$(tput setaf 2)
  cyan=$(tput setaf 6)
  normal=$(tput sgr0)

  IFS=" " read -a list < <(echo -e '\xe2\xa0\x8b \xe2\xa0\x99 \xe2\xa0\xb9 \xe2\xa0\xb8 \xe2\xa0\xbc \xe2\xa0\xb4 \xe2\xa0\xa6 \xe2\xa0\xa7 \xe2\xa0\x87 \xe2\xa0\x8f')
  tempfile=$(mktemp)

  trap 'cleanup' SIGINT

  stty -echo && tput civis
  $FUNCTION_NAME >> "$tempfile" 2>>"$tempfile" &
  local pid=$!

  tput sc
  printf "%s %s" "${list[i]}" "$green$1$normal"
  tput el
  tput rc

  while ps -p $pid -o pid= >/dev/null
  do
    printf "%s" "$cyan${list[i]}$normal"
    i=$(((i+1)%10))
    sleep $delay
    printf "\b\b\b"
  done
  tput el

  awk '{print}' "$tempfile"

  rm -f "$tempfile"

  tput cnorm && stty echo

  trap - SIGINT

  wait $pid
}

cfping() {
  local green red normal var
  green=$(tput setaf 2)
  red=$(tput setaf 1)
  normal=$(tput sgr0)

  cfping:help() {
    cat << EOF 1>&2
usage: 
      $_this -c [-l] [-s 2000] [-p 5] [-g 1] [-m 500]
        -c     ping [fping] all cloudflare ips to find the best ip
        -s <x> set the time in milliseconds that fping waits between successive 
               packets to an individual target (default is 2000, minimum is 10)
        -p <x> set the number of request packets to send to each target (default is 5)
        -g <x> the minimum amount of time (in milliseconds) between sending a 
               ping packet to any target (default is 1, minimum is 1)
        -l     show cloudflare ip location
        -m <x> you may want to use this according to system resources limit 
               larger number faster result (default is 500)

        ---

      $_this -d [-L https://domain.com/xxx] [-N 100] [-P 10] [-I ip]
        -d     speed test (default testing best 100 IPs unless -I used)
        -L <x> set the file link to test (default is a cloudflare worker linking to a file on www.apple.com)
               the domain of this link must have cname record on cloudflare
        -N <x> set the number of IPs to test (default is 100)
        -P <x> set the parallel number of speed test (default is 10)
        -I <x> specify an ip to test

        ---

      $_this [options] <start> <end>
        -n <x> set the number of addresses to print (<end> must not be set)
        -f <x> set the format of addresses (hex, dec, or dot)
        -i <x> set the increment to 'x'
        -h     display this help message and exit
        -v     display the version number and exit

EOF
    exit 1
  }

  cfping:info() {
    printf '%b' "\n  $*\n" 2>&1
  }

  cfping:error() {
    local code=1

    case ${1} in
      -[0-9]*)
       code=${1#-}
       shift
       ;;
    esac

    printf '%b' "\n   $_this: $red$*$normal\n\n" 1>&2
    exit "$code"
  }

  cfping:aton() {
    local ip=$1
    local ipnum=0

    for (( i=0; i<4; ++i )); do
      ((ipnum+=${ip%%.*}*$((256**$((3-i))))))
      ip=${ip#*.}
    done

    echo $ipnum
  }

  cfping:ntoa() {
    echo $(($(($(($((${1}/256))/256))/256))%256)).$(($(($((${1}/256))/256))%256)).$(($((${1}/256))%256)).$((${1}%256))
  }

  cfping:isint() {
    (( $1 > 0 )) 2>/dev/null
  }

  cfping:isip() {
    [[ $1 =~ ^[0-9]+(\.[0-9]+){3}$ ]]
  }

  cfping:printip() {
    cfping:set start "$1"
    cfping:set end "${2:-}" "$(( start + (increment * count) - 1 ))"

    [[ $end -lt $start ]] && \
      cfping:error "start address must be smaller than end address"

    if [[ $cf -eq 1 ]] 
    then
      oldstart=$start
      start=$((start+RANDOM%256))
    fi

    while [[ $start -le $end ]]; do
      if [[ $cf -eq 1 ]] 
      then
        cfping:ntoa "$start"
        oldstart=$(( oldstart + 256 ))
        start=$((oldstart+RANDOM%256))
      else
        case ${format} in
          dec)
            echo "$start"
            ;;
          hex)
            printf '%X\n' "$start"
            ;;
          *)
            cfping:ntoa "$start"
            ;;
        esac
        start=$(( start + increment ))
      fi
    done
  }

  cfping:genips() {
    local ip ips="" cidr
    while IFS= read -r line 
    do
      if [[ -n $line ]] 
      then
        # fping -q -i1 -c5 -p2000 -g 192.168.1.0/24
        ip=${line%/*}
        cidr=${line#*/}
        count=$((2**(32-cidr)-2))
        ips="$ips$(cfping:printip $ip)\n"
      fi
    done < <(wget --timeout=10 --tries=3 --no-check-certificate "https://www.cloudflare.com/ips-v4" -qO-)
    echo -ne "$ips" > ip
    if [ -s "ip" ] 
    then
      cfping:info "IPs in file: ${green}ip$normal"
    else
      cfping:error "connection problem ?"
    fi
  }

  cfping:testips() {
    echo > ip_checked
    echo > ip_location

    if [[ $location -eq 1 ]] 
    then
      awk '{print}' ip | xargs -L1 -P"$parallel" sh -c 'colo=$(curl -m 2 -s $0/cdn-cgi/trace | sed -n "s/colo=\(.*\)/\1/p"); if [ -n "$colo" ] ; then echo $0 $colo >> ip_location; fi'
      awk '{print $1}' ip_location > ip_checked
    else
      if [[ $(uname) == "Darwin" ]] 
      then
        awk '{print}' ip | xargs -L1 -P"$((parallel*2))" sh -c 'if nc -z -w 2 -G 2 $0 80 2> /dev/null; then echo $0 >> ip_checked; fi'
      else
        awk '{print}' ip | xargs -L1 -P"$((parallel*2))" sh -c 'if nc -z -w 2 $0 80 2> /dev/null; then echo $0 >> ip_checked; fi'
      fi
    fi
    if [ -s "ip_checked" ] 
    then
      cfping:info "valid IPs in file: ${green}ip_checked$normal"
    else
      cfping:error "connection problem ?"
    fi
  }

  cfping:pingips() {
    local best_ips exit_code ip_sorted
    fping -q -i"$interval" -c"$packets" -p"$mseconds" -x1 < ip_checked > ip_result 2>&1 || exit_code=$?

    if [[ ${exit_code:-0} -eq 1 ]] || [[ ${exit_code:-0} -eq 3 ]] || [[ ${exit_code:-0} -eq 4 ]]
    then
      if [[ $EUID -ne 0 ]] && [[ $interval -lt 10 ]]
      then
        interval=10
      fi

      exit_code=0
      fping -q -i"$interval" -c"$packets" -p"$mseconds" < ip_checked > ip_result 2>&1 || exit_code=$?

      if [[ $exit_code -gt 1 ]]
      then
        cfping:error "fping error, fping version too old or connection problem ?"
      fi
    fi

    awk '{split($5,a,"/");split($8,b,"/"); if($8) printf "%s packets received: %s ping: %s\n",$1,a[2],b[2] | "sort -k4,4rn -k6,6n" }' ip_result > ip_sorted
    if [[ $location -eq 1 ]] 
    then
      ip_sorted=$(awk 'NR==FNR{a[$1]=$2;next}{printf "%s location: %s\n",$0,a[$1]}' ip_location ip_sorted)
      echo "$ip_sorted" > ip_sorted
      best_ips=$(awk 'NR < 11 {printf "  %s\r\033[18Cpackets received: %s\033[3Cping: %s\033[3Clocation: %s\n",$1,$4,$6,$8}' ip_sorted)
    else
      best_ips=$(awk 'NR < 11 {printf "  %s\r\033[18Cpackets received: %s\033[3Cping: %s\n",$1,$4,$6}' ip_sorted)
    fi
    cfping:info "${green}10 BEST IPs$normal\n\n$best_ips\n\n  more IPs in file ${green}ip_sorted$normal\n"
    # echo -ne "$ips" | xargs -I {} -P"$parallel" sh -c "ping -c${packets} -q -W2 '{}' > '{}'.out 2>&1"
  }

  cfping:speedtestip() {
    curl --resolve "$st_domain:$st_port:$st_ip" "$st_link" -o "$st_ip" -s --connect-timeout 2 --max-time 10 || true
    if [ ! -s "$st_ip" ]
    then
      cfping:error "the domain of the file link must have cname record on cloudflare or try again"
    fi
    if [[ $(uname) == "Darwin" ]] 
    then
      stat -f '%N %z' $st_ip | awk '{printf "\n  %s\r\033[18Cspeed: %.2f MB/10s\n\n",$1,$2/1024/1024}'
    else
      find $st_ip -type f -printf '%p %s\n' | awk '{printf "\n  %s\r\033[18Cspeed: %.2f MB/10s\n\n",$1,$2/1024/1024}'
    fi
    rm -f ${st_ip:-notfound}
  }

  cfping:speedtestips() {
    mkdir -p cf_speed_test
    awk 'NR <= '"$st_num"' {print $1}' ip_sorted | xargs -L1 -P"$st_parallel" sh -c 'curl --resolve '"$st_domain:$st_port"':$0 "'"$st_link"'" -o cf_speed_test/$0 -s --connect-timeout 2 --max-time 10 || true'
    cd cf_speed_test
    if [[ $(uname) == "Darwin" ]] 
    then
      ip_speed_test=$(find -- * -type f -print0 | xargs -0 stat -f '%N %z' | sort -k2,2rn | awk '{printf "%s %.2f MB\n",$1,$2/1024/1024}')
      # rm -- *
    else
      ip_speed_test=$(find -- * -type f -printf '%p %s\n' | sort -k2,2rn | awk '{printf "%s %.2f MB\n",$1,$2/1024/1024}')
    fi
    cd ..
    rm -rf cf_speed_test
    echo "$ip_speed_test" > ip_speed_test
    ip_speed_test=$(awk 'NR==FNR{a[$1]=$0;next}{printf "%s speed: %s MB/10s\n",a[$1],$2}' ip_sorted ip_speed_test)
    echo "$ip_speed_test" > ip_speed_test
    awk '{if($10) printf "  %s\r\033[18Cpackets received: %s\033[3Cping: %s\033[3Clocation: %s\033[3Cspeed: %s MB/10s\n",$1,$4,$6,$8,$10; else printf "  %s\r\033[18Cpackets received: %s\033[3Cping: %s\033[3Cspeed: %s MB/10s\n",$1,$4,$6,$8}' ip_speed_test
    cfping:info "${green}Done.$normal\n"
  }

  cfping:set() {
    var=$1
    local val=${2:-$3}

    case ${var} in
      c)
        var="cf"
        args=0
        ;;
      d)
        var="st"
        args=0
        ;;
      L)
        var="st_link"
        ;;
      N)
        var="st_num"
        ;;
      P)
        var="st_parallel"
        ;;
      I)
        var="st_ip"
        ;;
      s)
        var="mseconds"
        ;;
      p)
        var="packets"
        ;;
      g)
        var="interval"
        ;;
      m)
        var="parallel"
        ;;
      l)
        var="location"
        ;;
      f)
        var="format"

        ! echo "${_formats[@]}" | grep -qw "$val" && \
          cfping:error "invalid format '$val'"
        ;;
      i)
        var="increment"

        ! cfping:isint "$val" && \
          cfping:error "$var must be a positive integer"
        ;;
      n)
        var="count"

        ! cfping:isint "$val" && \
          cfping:error "$var must be a positive integer"

        args=1
        ;;
      t)
        var="_this"
        ;;
      start | end)
        if cfping:isip "$val" 
        then
          val=$(cfping:aton "$val")
          [[ $cf -eq 1 ]] && val=$((val+1))
        fi

        [[ $cf -eq 1 ]] && val=$((val+1))

        ! cfping:isint "$val" && \
          cfping:error "bad IP address"
        ;;
    esac

    read -r ${var?} <<< "$val"
  }

  local _formats=("dec" "dot" "hex")
  local _this="cfping"
  local _version="0.1.3"

  local cf=0
  local st=0
  local st_num=100
  local st_link="https://www-apple-com.mtimer.workers.dev/105/media/us/iphone-11-pro/2019/3bd902e4-0752-4ac1-95f8-6225c32aec6d/films/product/iphone-11-pro-product-tpl-cc-us-2019_1280x720h.mp4"
  local st_parallel=10
  local st_ip=""
  local mseconds=2000
  local packets=5
  local interval=1
  local parallel=500
  local location=0
  local args=2
  local count=0
  local increment=1
  local format="dot"
  local start
  local end

  while getopts "f:i:n:t:p:s:g:m:L:N:P:I:?hvcld" opt; do
    case ${opt} in
      f | i | n | t | p | s | g | m | L | N | P | I)
        cfping:set "$opt" "$OPTARG"
        ;;
      c | l | d)
        cfping:set "$opt" 1
        ;;
      v)
        cfping:error -0 "v$_version"
        ;;
      h | \? | :)
        cfping:help
        ;;
    esac
  done
  shift $((OPTIND -1))

  if [ $# -ne $args ]; then
    cfping:help
  fi

  if [[ $cf -eq 1 ]] 
  then
    if [[ ! -x $(command -v fping) ]] 
    then
      archs=( 'Mac' 'CentOS' 'Ubuntu/Debian' 'Fedora 22+' 'Arch Linux' )
      list_input "What's your system ?" archs arch_selected

      case $arch_selected in
        "Mac") 
          brew install fping
        ;;
        "CentOS") 
          yum -y install fping
        ;;
        "Ubuntu/Debian") 
          apt-get -y install fping
        ;;
        "Fedora 22+") 
          dnf install fping
        ;;
        "Arch Linux") 
          pacman -S fping
        ;;
      esac
    fi

    spinner "generating cloudflare IPs" cfping:genips
    spinner "testing IPs, 2 mins" cfping:testips
    spinner "pinging cloudflare IPs, 1 min" cfping:pingips

  elif [[ $st -eq 1 ]] 
  then
    if [ ! -s "ip_sorted" ] 
    then
      cfping:error "no IPs found, run $_this -c"
    fi
    if [[ ${st_link:0:5} == "https" ]] 
    then
      st_port=443
    else
      st_port=80
    fi
    st_domain=${st_link#*http://}
    st_domain=${st_domain%%/*}
    st_domain=${st_domain%:*}
    if cfping:isip "$st_domain" 
    then
      cfping:error "wrong file link, use domain"
    fi
    if [ -n "$st_ip" ] 
    then
      spinner "testing IP $st_ip" cfping:speedtestip
    else
      spinner "speed testing $st_num IPs, 2 mins" cfping:speedtestips
    fi
  else
    cfping:printip "$@"
  fi
}

if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  cfping -t "$(basename "$0")" "$@"
fi