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

    -i "<target_Id>"

       必須

   [-o <Organizer_account>]

      省略時は第一引数 (も無ければ コマンド実行ユーザ名 ($( whoami )${DEF_DOMAIN}) )

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

arg_flag_print_postxml=0
arg_flag_print_outjson=0
arg_flag_print_outxml=0
arg_flag_print_procfulljson=0
arg_flag_print_procmediumjson=1
arg_flag_verbose=0
arg_targetid=
arg_organizer=
while getopts "fhi:jmopvx" arg; do
  case ${arg} in
    f) arg_flag_print_procfulljson=1;;
    h) func_usage; exit 0;;
    i) arg_targetid="${OPTARG}";;
    j) arg_flag_print_outjson=1;;
    m) arg_flag_print_procmediumjson=1;;
    o) arg_organizer="${OPTARG}";;
    p) arg_flag_print_postxml=1;;
    v) arg_flag_verbose=1;;
    x) arg_flag_print_outxml=1;;
   \?) func_usage; exit 1;;
  esac
done
shift $(( OPTIND - 1 ))

if [[ -z "${arg_targetid}" ]]; then
    set +u
    if [[ -n "$1" ]]; then
        arg_targetid=$1
    fi
    set -u
fi

[[ -z "${arg_targetid}" ]] && { func_usage; echo >&2 "err: need -i option"; exit 9; }

if [[ -z "${arg_organizer}" ]]; then
    organizer=$( whoami )
else
    organizer=${arg_organizer}
fi
organizer=$( func_offcet_domain ${organizer} )

sed \
  -e 's,XXX_Id_XXX,'"${arg_targetid}"',' \
  -e 's,XXX_ORGANIZER_XXX,'${organizer}',' \
  ${CONVERTID_XML} \
  > ${INPUT_XML}

if [[ ${arg_flag_print_postxml} -eq 1 ]] || [[ ${arg_flag_verbose} -eq 1 ]]; then
    echo >&2 "debug: print Post_XML"
    cat >&2 ${INPUT_XML}
    echo >&2
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

jq -r '.Envelope.Body.ConvertIdResponse.ResponseMessages.ConvertIdResponseMessage' ${RET_JSON} > ${EXTRACTED_JSON}

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

    jq '.AlternateId' ${EXTRACTED_JSON}

else

    jq -r '.AlternateId.Id' ${EXTRACTED_JSON}

fi

exit
