#!/bin/bash

set -u

export LANG=ja_JP.UTF-8
export PATH=/sbin:/bin:/usr/sbin:/usr/bin

readonly MY_PATH=$( readlink -f $0 )
readonly MY_NAME=$( basename ${MY_PATH} .sh )
readonly MY_DIR=$( dirname ${MY_PATH} )
source ${MY_DIR}/SHELLSCRIPT_CONFIG
cd ${MY_DIR}/../ || exit $?

trap 'rm -f ${TMP_BASEFILE:-XX_NULL_XX}*' 0 1 2 3 15


function func_usage() {
    echo >&2 -e "\n  \$ $0"
    cat >&2 << EOS

   [-h]
       print usage

  =================================================

   [-s <Start_date>]

      省略時は本日

   [-e <End_date>]

      省略時は <Start_date> と同じ日
      あとは <Start_date> と

    -r <Room名 | Room Address>

      必須

    ------------------------------

   [-d]
       Dryrun

   [-p]
       debug-print Post_xml

   [-j]
       debug-print output_Json

   [-x]
       print output_Xml only (即終了)

   [-v]
       debug-print input_xml,output_xml,output_json

EOS
}

arg_flag_dryrun=0
arg_flag_print_postxml=0
arg_flag_print_outjson=0
arg_flag_print_outxml=0
arg_flag_print_quiet=0
arg_flag_verbose=0
arg_start_date=
arg_end_date=
arg_room=
while getopts "de:hjpqs:r:vx" arg; do
  case ${arg} in
    d) arg_flag_dryrun=1;;
    e) arg_end_date="${OPTARG}";;
    h) func_usage; exit 0;;
    j) arg_flag_print_outjson=1;;
    p) arg_flag_print_postxml=1;;
    q) arg_flag_print_quiet=1;;
    s) arg_start_date="${OPTARG}";;
    r) arg_room="${OPTARG}";;
    v) arg_flag_verbose=1;;
    x) arg_flag_print_outxml=1;;
   \?) func_usage; exit 1;;
  esac
done
shift $(( OPTIND - 1 ))

if [[ -z "${arg_room}" ]]; then
    set +u
    if [[ -n "$1" ]]; then
        arg_room=$1
    else
        func_usage
        echo >&2 "err: need -r option"
        exit 9;
    fi
    set -u
fi

supple_domain=${DEF_DOMAIN}
echo ${arg_room} | fgrep -q "@" && supple_domain=

echo ${arg_room} | fgrep -q "@"
if [[ $? -eq 0 ]]; then
    room_addr="${arg_room}"
    room_name="$( jq -r "select( .room_Address == \"${room_addr}\" ) | .room_Name" ${ROOM_CONF} )"
else
    room_name="${arg_room}"
    room_addr="$( jq -r "select( .room_Name == \"${room_name}\" ) | .room_Address" ${ROOM_CONF} )"
  if [[ -z "${room_addr}" ]]; then
    room_addr="${arg_room}${supple_domain}"
    room_name="$( jq -r "select( .room_Address == \"${room_addr}\" ) | .room_Name" ${ROOM_CONF} )"
  fi
fi

if [[ -z "${room_addr}" ]] || [[ -z "${room_name}" ]]; then
    echo >&2 "err: [room_addr:${room_addr}], [room_name:${room_name}]"
    exit 9
fi


echo "${arg_start_date}" \
| grep -qE "^[+-]?[1-9][0-9]*$" \
&& arg_start_date=$( date +%Y-%m-%d -d"${arg_start_date} day" )
[[ -z "${arg_start_date}" ]] && arg_start_date=$( date +%Y-%m-%d )

echo "${arg_end_date}" \
| grep -qE "^[+-]?[1-9][0-9]*$" \
&& arg_end_date=$( date +%Y-%m-%d -d"${arg_start_date} ${arg_end_date} day" )
[[ -z "${arg_end_date}" ]] && arg_end_date=${arg_start_date}

START_DATE=$( date +%Y-%m-%d -d"${arg_start_date}" ) || exit $?
END_DATE=$(   date +%Y-%m-%d -d"${arg_end_date}" )   || exit $?

echo >&2 "[target]: ${room_name} (${room_addr})"
echo >&2 "[term]: ${START_DATE}T00:00 - ${END_DATE}T31:59($( date -d"${END_DATE} 1 day" +%Y-%m-%d )T08:59)"

sed \
  -e 's,XX_START_DATE_XX,'${START_DATE}',' \
  -e 's,XX_END_DATE_XX,'${END_DATE}',' \
  -e 's,XX_TARGET_ROOM_XX,'${room_addr}',' \
  ${GETUSERAVAIl_XML} \
  > ${INPUT_XML}

if [[ ${arg_flag_print_postxml} -eq 1 ]] || [[ ${arg_flag_verbose} -eq 1 ]]; then
    echo >&2 "debug: print Post_XML"
    cat >&2 ${INPUT_XML}
    echo >&2
fi

if [[ ${arg_flag_dryrun} -eq 1 ]]; then
     echo "[dryrun]:" "${EX_CURL[@]}" -d@${INPUT_XML} -o ${OUTPUT_XML}
     exit
fi
"${EX_CURL[@]}" -d@${INPUT_XML} -o ${OUTPUT_XML}

xmllint --format ${OUTPUT_XML} >/dev/null 2>&1 \
|| { xmllint --format ${OUTPUT_XML}; exit 8; }

if [[ ${arg_flag_print_outxml} -eq 1 ]]; then
    echo >&2 "debug: print Output_XML (finish)"
   #cat >&2 ${OUTPUT_XML}
    cat ${OUTPUT_XML}
    exit
fi
if [[ ${arg_flag_verbose} -eq 1 ]]; then
    echo >&2 "debug: print Output_XML"
    cat >&2 ${OUTPUT_XML}
    echo >&2
fi

cat ${OUTPUT_XML} | ${XM2JSON_SCRIPT} > ${RET_JSON}

if [[ ${arg_flag_print_outjson} -eq 1 ]] || [[ ${arg_flag_verbose} -eq 1 ]]; then
    echo >&2 "debug: print Output_JSON"
    cat >&2 ${RET_JSON}
    echo >&2
fi

res_class=$( jq -r '
  .Envelope.Body.GetUserAvailabilityResponse.FreeBusyResponseArray.FreeBusyResponse
  | .ResponseMessage.ResponseClass
' ${RET_JSON} )
if [[ "${res_class}" != Success ]]; then
    res_faultmsg=$( jq -r '.Envelope.Body.Fault.detail.Message' ${RET_JSON} )
    if [[ -z "${res_faultmsg}" ]]; then
        echo >&2 "err: Unknown Error"
        exit 7
    else
        echo >&2 "err: ${res_faultmsg}"
        exit 6
    fi
fi

cat ${RET_JSON} \
| jq -r '
  .Envelope.Body.GetUserAvailabilityResponse.FreeBusyResponseArray.FreeBusyResponse
  | .FreeBusyView.CalendarEventArray.CalendarEvent
  | if type == "array" then
      map( [.StartTime, .EndTime, .CalendarEventDetails.Subject])[] | @csv
    elif type == "null" then
      empty
    else
           [.StartTime, .EndTime, .CalendarEventDetails.Subject]    | @csv
    end
' \
| perl -pe 's/(\d\d:\d\d):00"/$1"/g'\
| sed -e 's/","/,/g' -e 's/^"//' -e 's/"$//'

exit
