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

"${EX_CURL[@]}" -d@${GETROOMLIST_XML} -o ${OUTPUT_XML}
cat ${OUTPUT_XML} | ${XM2JSON_SCRIPT} > ${RET_JSON}

res_class=$( jq -r '.Envelope.Body.GetRoomListsResponse.ResponseClass' ${RET_JSON} )
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

:> ${OUTPUT_JSON}

while read roomList_Address roomList_Name; do

    echo >&2 "[get] ${roomList_Address} / ${roomList_Name}"

    sleep 3
    ret_xml=${OUTPUT_XML}_rooms
    ret_json=${RET_JSON}_rooms

    "${EX_CURL[@]}" -d"$( sed 's/XX_EMAIL_ADDRESS_XX/'${roomList_Address}'/' ${GETROOMS_XML} )" -o ${ret_xml}
    cat ${ret_xml} | ${XM2JSON_SCRIPT} > ${ret_json}

    res_class=$( jq -r '.Envelope.Body.GetRoomsResponse.ResponseClass' ${ret_json} )
    if [[ "${res_class}" != Success ]]; then
        res_faultmsg=$( jq -r '.Envelope.Body.Fault.detail.Message' ${ret_json} )
        if [[ -z "${res_faultmsg}" ]]; then
            echo >&2 "err: Unknown Error: ${roomList_Address} (${roomList_Name})"
            exit 5
        else
            echo >&2 "err: ${res_faultmsg}: ${roomList_Address} (${roomList_Name})"
            exit 4
        fi
    fi

    cat ${ret_json} \
    | jq -r ".Envelope.Body.GetRoomsResponse | select( .Rooms != null ) | .Rooms.Room[].Id | [ .EmailAddress, .Name ] | @csv" \
    | tr -d '"' \
    | sed 's/,/\t/' \
    | while read room_Address room_Name; do

        cat <<EOS | tee -a ${OUTPUT_JSON} | jq .
{
  "roomList_Name": "${roomList_Name}",
  "roomList_Address": "${roomList_Address}",
  "room_Name": "${room_Name}",
  "room_Address": "${room_Address}"
}
EOS

    done

done < <(
  cat ${RET_JSON} \
  | jq -r ".Envelope.Body.GetRoomListsResponse.RoomLists.Address | map( [ .EmailAddress, .Name ] )[] | @csv" \
  | tr -d '"' \
  | sed 's/,/\t/'
)

mv -f ${OUTPUT_JSON} ${ROOM_CONF}
echo >&2 "update of ${ROOM_CONF} completed"

exit
