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

    -t "<Title>"

    省略不可
    予定タイトル (XML 要素で言えば Subject)

   [-b "<Body_msg>"]

    予定詳細部

    -s "<Start_datetime>"

      省略不可
      date -d コマンド が解釈できる形式で指定する ("YYYY-mm-dd HH:MM" 等)

   [-e "<End_datetime>"|<HOUR>]

      date -d コマンド が解釈できる形式で指定する ("YYYY-mm-dd HH:MM" 等)
      または <Start_datetime> からの経過時間 (hour) を自然数で指定する
      省略時は <Start_datetime> の 1h 後

   [-o <Organizer_account>]

      省略時は第一引数 (も無ければ コマンド実行ユーザ名 ($( whoami )${DEF_DOMAIN}) )

   [-u <User_account>[,<User_account>...]]

   [-r <Room>[,<Room>...]]

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

function func_offcet_domain() {
    local f_arg=$1
    echo ${f_arg} | fgrep -q "@"
    if [[ $? -eq 0 ]]; then
        echo ${f_arg}
    else
        echo ${f_arg}${DEF_DOMAIN}
    fi
    return
}

arg_flag_dryrun=0
arg_flag_print_postxml=0
arg_flag_print_outjson=0
arg_flag_print_outxml=0
tag_xmltype=
type_info='(brief)'
arg_flag_verbose=0
arg_end=1
arg_organizer=
arg_rooms=
arg_users=
arg_title=
arg_body=
start_datetime=
while getopts "b:de:hjo:pr:s:t:u:vx" arg; do
  case ${arg} in
    b) arg_body="${OPTARG}";;
    d) arg_flag_dryrun=1;;
    e) arg_end="${OPTARG}";;
    h) func_usage; exit 0;;
    j) arg_flag_print_outjson=1;;
    p) arg_flag_print_postxml=1;;
    o) arg_organizer="${OPTARG}";;
    r) arg_rooms="${OPTARG}";;
    s) start_datetime=$( date +%Y-%m-%dT%H:%M -d"${OPTARG}" ) || exit $?;;
    t) arg_title="${OPTARG}";;
    u) arg_users="${OPTARG}";;
    v) arg_flag_verbose=1;;
    x) arg_flag_print_outxml=1;;
   \?) func_usage; exit 1;;
  esac
done
shift $(( OPTIND - 1 ))

[[ -z "${arg_title}" ]]      && { func_usage; echo >&2 "err: need -t option"; exit 9; }
[[ -z "${start_datetime}" ]] && { func_usage; echo >&2 "err: need -s option"; exit 9; }

if [[ -z "${arg_organizer}" ]]; then
    organizer=$( whoami )
else
    organizer=${arg_organizer}
fi
organizer=$( func_offcet_domain ${organizer} )

echo "${arg_end}" | grep -qE "^[+-]?[1-9][0-9]*$"
if [[ $? -eq 0 ]]; then
    end_datetime=$( date +%Y-%m-%dT%H:%M -d"${start_datetime} ${arg_end} hour" ) || exit $?
else
    end_datetime=$( date +%Y-%m-%dT%H:%M -d"${arg_end}" ) || exit $?
fi

declare -a arr_users=("${organizer}")
while read arg_user; do
    [[ -z "${arg_user}" ]] && break
    arr_users+=( $( func_offcet_domain ${arg_user} ) )
done < <( echo "${arg_users}" | tr ',' '\n' | sort -u )

declare -a arr_rooms_name=()
declare -a arr_rooms_addr=()
while read arg_room; do
    [[ -z "${arg_room}" ]] && break

    ret_addr=$( jq -r "select( .room_Name == \"${arg_room}\" ) | .room_Address" ${ROOM_CONF} )
    if [[ -n "${ret_addr}" ]]; then
        arr_rooms_name+=( "${arg_room}" )
        arr_rooms_addr+=( "${ret_addr}" )
        continue
    fi

    arg_room_addr=$( func_offcet_domain ${arg_room} )
    ret_name=$( jq -r "select( .room_Address == \"${arg_room_addr}\" ) | .room_Name" ${ROOM_CONF} )
    if [[ -n "${ret_name}" ]]; then
        arr_rooms_name+=( "${ret_name}" )
        arr_rooms_addr+=( "${arg_room_addr}" )
        continue
    fi

    echo >&2 "err: ${arg_room} can not be found in ${ROOM_CONF}"
    exit 8
done < <( echo "${arg_rooms}" | tr ',' '\n' | sort -u )

echo >&2 "[organizer]: ${organizer}"
echo >&2 "[term]: ${start_datetime} - ${end_datetime}"
echo >&2 "[user]: $( [[ ${#arr_users[@]} -ge 1 ]] && echo ${arr_users[@]} )"
echo >&2 "[room]: $( [[ ${#arr_rooms_addr[@]} -ge 1 ]] && echo ${arr_rooms_name[@]} )"

users_addr_tag="$(
  i=0
  while [[ ${#arr_users[@]} -gt ${i} ]]; do
    echo -n "<t:Attendee><t:Mailbox><t:EmailAddress>${arr_users[${i}]}</t:EmailAddress></t:Mailbox></t:Attendee>"
    i=$(( ${i} + 1 ))
  done
)"
rooms_name="$(
  i=0
  while [[ ${#arr_rooms_name[@]} -gt ${i} ]]; do
    echo -n "${arr_rooms_name[${i}]},"
    i=$(( ${i} + 1 ))
  done | sed 's/,$//'
)"
rooms_addr_tag="$(
  i=0
  while [[ ${#arr_rooms_addr[@]} -gt ${i} ]]; do
    echo -n "<t:Attendee><t:Mailbox><t:EmailAddress>${arr_rooms_addr[${i}]}</t:EmailAddress></t:Mailbox></t:Attendee>"
    i=$(( ${i} + 1 ))
  done
)"

(
 sed \
  -e 's,XXX_ORGANIZER_XXX,'${organizer}',' \
  -e 's,XXX_StartTime_XXX,'${start_datetime}',' \
  -e 's,XXX_EndTime_XXX,'${end_datetime}',' \
  -e 's,XXX_USER_ADDR_TAG_XXX,'"${users_addr_tag}"',' \
  -e 's,XXX_ROOM_ADDR_TAG_XXX,'"${rooms_addr_tag}"',' \
  -e 's/XXX_ROOM_NAME_XXX/'${rooms_name}'/' \
  ${CREATEITEM_FIRST_XML}

 echo -n '          <t:Subject>'
 echo -n "$( echo -n "${arg_title}" | ${ESCAPE_SCRIPT} )"
 echo    '</t:Subject>'

 echo -n '          <t:Body BodyType="HTML">'
 echo -n "$( echo -n "${arg_body}" | ${ESCAPE_SCRIPT} )"
 echo    '</t:Body>'

  cat ${CREATEITEM_LAST_XML}
) > ${INPUT_XML}

if [[ ${arg_flag_print_postxml} -eq 1 ]] || [[ ${arg_flag_verbose} -eq 1 ]]; then
    echo >&2 "debug: print Post_XML"
    xmllint --format ${INPUT_XML} >&2
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

jq '.Envelope.Body.CreateItemResponse.ResponseMessages.CreateItemResponseMessage' ${RET_JSON} > ${EXTRACTED_JSON}

res_class=$( jq -r '.ResponseClass' ${EXTRACTED_JSON} )
if [[ "${res_class}" != Success ]]; then
    res_faultmsg=$( jq -r '.MessageText' ${EXTRACTED_JSON} )
    if [[ -z "${res_faultmsg}" ]]; then
        echo >&2 "err: Unknown Error"
        exit 7
    else
        echo >&2 "err: ${res_faultmsg}"
        exit 6
    fi
fi

cat ${EXTRACTED_JSON} \
| ${BIN_DIRNAME}/parse_json.py \
| jq '.Items.CalendarItem.ItemId'

exit
