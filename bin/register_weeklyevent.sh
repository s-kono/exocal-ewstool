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

   [-d]
       Dryrun

   [-q]
       Quiet

   [-v]
       debug-print

EOS
}

arg_flag_dryrun=0
arg_flag_verbose=0
arg_flag_quiet=0
while getopts "dhqv" arg; do
  case ${arg} in
    d) arg_flag_dryrun=1;;
    h) func_usage; exit 0;;
    q) arg_flag_quiet=1;;
    v) arg_flag_verbose=1;;
   \?) func_usage; exit 1;;
  esac
done
shift $(( OPTIND - 1 ))

[[ -e "${WEEKLYEVENT_CONF}" ]] || { echo >&2 "err: notfound ${WEEKLYEVENT_CONF}"; exit 9; }

readonly TARGET_DAY_OF_THE_WEEK=$( LC_ALL=C date +%a -d"${REGISTERABLE_START_SHIFTDAYS} days" )
readonly TARGET_DATE=$( date +%Y/%m/%d -d"${REGISTERABLE_START_SHIFTDAYS} days" )

grep -P "^${TARGET_DAY_OF_THE_WEEK}\t" ${WEEKLYEVENT_CONF} \
| while IFS=$'\t' read day_of_week title organizer users rooms start_time end_time body; do

    opt_users=
    [[ "${users}" != '-' ]] && opt_users="-u \"${users}\""
    opt_rooms=
    [[ "${rooms}" != '-' ]] && opt_rooms="-r \"${rooms}\""
    opt_body=
    [[ "${body}"  != '-' ]] && opt_body="-b \"${body}\""

    run_command="${CREATECAL_SCRIPT} -o ${organizer} ${opt_users} ${opt_rooms} ${opt_body} -t \"${title}\" -s \"${TARGET_DATE} ${start_time}\" -e \"${TARGET_DATE} ${end_time}\""

    if [[ ${arg_flag_dryrun} -eq 1 ]]; then
        echo "[dryrun]:" ${run_command}
        continue
    fi

    eval ${run_command} >${TMP_BASEFILE}.out 2>${TMP_BASEFILE}.err

    if [[ ${arg_flag_verbose} -eq 1 ]]; then

        echo >&2 "[run]:" ${run_command}
        sleep 2
        cat ${TMP_BASEFILE}.err >&2
        id=$(  jq -r '.Id'        ${TMP_BASEFILE}.out )
        key=$( jq -r '.ChangeKey' ${TMP_BASEFILE}.out )
        ${GETCAL_SCRIPT} -i "${id}" -k "${key}"

    elif [[ ${arg_flag_quiet} -eq 1 ]]; then
        :
    else
        cat ${TMP_BASEFILE}.err >&2
        cat ${TMP_BASEFILE}.out
    fi

    sleep 2

done

exit
