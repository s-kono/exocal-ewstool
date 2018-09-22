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

    -i "<Calendaritem_Id>"

       必須

    -k "<Calendaritem_ChangeKey>"

       必須

  =================================================

   [-f|-m]

     -f: print processing_Full_json
     -m: print processing_Medium_json [default]

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
arg_flag_print_procfulljson=0
arg_flag_print_procmediumjson=1
arg_flag_verbose=0
arg_calendarid=
arg_calendarkey=
while getopts "bdfhi:jk:mpvx" arg; do
  case ${arg} in
    b) :;;
    d) arg_flag_dryrun=1;;
    f) arg_flag_print_procfulljson=1;;
    h) func_usage; exit 0;;
    i) arg_calendarid="${OPTARG}";;
    j) arg_flag_print_outjson=1;;
    k) arg_calendarkey="${OPTARG}";;
    m) arg_flag_print_procmediumjson=1;;
    p) arg_flag_print_postxml=1;;
    v) arg_flag_verbose=1;;
    x) arg_flag_print_outxml=1;;
   \?) func_usage; exit 1;;
  esac
done
shift $(( OPTIND - 1 ))

[[ -z "${arg_calendarid}" ]] && { func_usage; echo >&2 "err: need -i option"; exit 9; }
[[ -z "${arg_calendarkey}" ]] && { func_usage; echo >&2 "err: need -k option"; exit 9; }

sed \
  -e 's,XXX_ItemId_Id_XXX,'"${arg_calendarid}"',' \
  -e 's,XXX_ItemId_ChangeKey_XXX,'${arg_calendarkey}',' \
  ${GETITEM_XML} \
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

jq -r '.Envelope.Body.GetItemResponse.ResponseMessages.GetItemResponseMessage' ${RET_JSON} > ${EXTRACTED_JSON}

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

if [[ ${arg_flag_print_procfulljson} -eq 1 ]]; then

    cat ${EXTRACTED_JSON} \
    | ${BIN_DIRNAME}/parse_json.py \
    | jq '.Items.CalendarItem'

else

    cat ${EXTRACTED_JSON} \
    | ${BIN_DIRNAME}/parse_json.py \
    | jq '.Items.CalendarItem |
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
    "ConflictingMeetingCount": .ConflictingMeetingCount,
    "ConflictingMeetings": .ConflictingMeetings,
  }
    '

fi

exit
