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
      <Start_date> は date コマンドが解釈できる形式 (YYYY-MM-DD, MM/DD 等) か、整数値 (本日基点の差分日数)

   [-e <End_date>]

      省略時は <Start_date> と同じ日
      整数値を指定した場合の基点は <Start_date> の指定日

   [-u <User_account>]

      省略時は第一引数 (も無ければ コマンド実行ユーザ名 ($( whoami )${DEF_DOMAIN}) )

    ------------------------------

   [-f|-m|-b]

     -f: print processing_Full_json

     -m: print processing_Medium_json

     -b: print processing_Brief_json [default]
         (.IsCancelled = true な予定は除外)

   [-d]
       Dryrun

   [-p]
       debug-print Post_xml

   [-j]
       debug-print output_Json

   [-q]
       合致する予定が無い場合、標準出力に何も出力しない

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
tag_xmltype=
type_info='(brief)'
arg_flag_print_procfulljson=0
arg_flag_print_procmediumjson=0
arg_flag_print_procbriefjson=1
arg_flag_print_quiet=0
arg_flag_verbose=0
arg_start_date=
arg_end_date=
arg_user=
while getopts "bde:fhjmpqs:u:vx" arg; do
  case ${arg} in
    b) arg_flag_print_procbriefjson=1;;
    d) arg_flag_dryrun=1;;
    e) arg_end_date="${OPTARG}";;
    f) arg_flag_print_procfulljson=1; tag_xmltype=_full; type_info='(full)';;
    h) func_usage; exit 0;;
    j) arg_flag_print_outjson=1;;
    p) arg_flag_print_postxml=1;;
    m) arg_flag_print_procmediumjson=1; tag_xmltype=_medium; type_info='(medium)';;
    q) arg_flag_print_quiet=1;;
    s) arg_start_date="${OPTARG}";;
    u) arg_user="${OPTARG}";;
    v) arg_flag_verbose=1;;
    x) arg_flag_print_outxml=1;;
   \?) func_usage; exit 1;;
  esac
done
shift $(( OPTIND - 1 ))

if [[ -z "${arg_user}" ]]; then
    set +u
    if [[ -z "$1" ]]; then
        arg_user=$( whoami )
    else
        arg_user=$1
    fi
    set -u
fi

supple_domain=${DEF_DOMAIN}
echo ${arg_user} | fgrep -q "@" && supple_domain=

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

echo >&2 "[target]: ${arg_user}${supple_domain} ${type_info}"
echo >&2 "[term]: ${START_DATE}T00:00 - ${END_DATE}T31:59($( date -d"${END_DATE} 1 day" +%Y-%m-%d )T08:59)"

sed \
  -e 's,XX_MAX_ENTRIES_XX,'${MAX_ENTRIES}',' \
  -e 's,XX_START_DATE_XX,'${START_DATE}',' \
  -e 's,XX_END_DATE_XX,'${END_DATE}',' \
  -e 's,XX_TARGET_ACCOUNT_XX,'${arg_user}',' \
  -e 's,XX_TARGET_DOMAIN_XX,'${supple_domain}',' \
  ${CALENDARVIEW_XML}${tag_xmltype} \
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

jq '.Envelope.Body.FindItemResponse.ResponseMessages.FindItemResponseMessage' ${RET_JSON} > ${EXTRACTED_JSON}

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

jq '.RootFolder' ${EXTRACTED_JSON} > ${ITEMROOT_JSON}

if [[ $( jq -r '.TotalItemsInView' ${ITEMROOT_JSON} ) -eq 0 ]]; then
    [[ ${arg_flag_print_quiet} -eq 0 ]] && jq . ${ITEMROOT_JSON}
    exit
fi

if [[ ${arg_flag_print_procfulljson} -eq 1 ]]; then
    cat ${ITEMROOT_JSON} \
    | ${BIN_DIRNAME}/parse_json.py \
    | jq .
else
    cat ${ITEMROOT_JSON} \
    | ${BIN_DIRNAME}/parse_json.py \
    | jq '
  if .TotalItemsInView > 1 then
    .Items.CalendarItem[]
  else
    .Items.CalendarItem
  end
    ' \
    > ${PROC_JSON}

  (
    if [[ ${arg_flag_print_procmediumjson} -eq 1 ]]; then

        jq '
  {
    "Start": .Start,
    "End": .End,
    "Subject": .Subject,
    "IsAllDayEvent": .IsAllDayEvent,
    "Location": .Location,
    "To": .DisplayTo,
    "Cc": .DisplayCc,
    "IsCancelled": .IsCancelled,
    "Sensitivity": .Sensitivity,
    "Preview": .Preview,
    "LegacyFreeBusyStatus": .LegacyFreeBusyStatus,
    "DateTimeCreated": .DateTimeCreated,
    "LastModifiedTime": .LastModifiedTime,
    "Organizer": .Organizer.Mailbox.Name,
    "ItemId": .ItemId,
  }
        ' ${PROC_JSON}

    else

        jq 'select(.IsCancelled == "false") |
  {
    "Start": .Start,
    "End": .End,
    "Subject": .Subject,
    "IsAllDayEvent": .IsAllDayEvent,
    "Location": .Location,
  }
        ' ${PROC_JSON} \
        | sed 's% "20[1-9][0-9]-\([01][0-9]\)-\([0-3][0-9] \)% "\1/\2%' \
        | jq -c 'to_entries
  | [ .[]
    | if .value == null then empty else . end
    | if .value == "false" then empty else . end
  ] | from_entries'

    fi
  )
fi

item_count=$( jq -r '.TotalItemsInView' ${ITEMROOT_JSON} )
if [[ ${item_count} -gt ${MAX_ENTRIES} ]]; then
    echo >&2 "warn: overentry:${item_count} (>${MAX_ENTRIES})"
fi

exit
