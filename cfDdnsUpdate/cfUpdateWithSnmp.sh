#!/bin/bash
set -o errexit
set -o xtrace # DEBUG 
set -o nounset

cfLogin=""
cfSecret=""
cfDomain=""
cfRecordNames=""

mkHostIp=""
mkSnmpCommunity=""
mkSnmpIfId=""

TEMP_DIR=$(mktemp -d) # create a temp only us can rw from/to
ETC_FOLDER="${HOME}/etc"
STATUS_FILE="$ETC_FOLDER/IPStatus"

function snmpGetIP
{
    local SNMP_HOST=$1
    local SNMP_COMM=$2
    local SNMP_IFID=$3

    snmpwalk -Os -c ${SNMP_COMM} -v 2c ${SNMP_HOST} ipAdEntIf | grep "INTEGER: ${SNMP_IFID}" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'
}

function cfGetZone
{
    curl -sX "GET" "https://api.cloudflare.com/client/v4/zones/" \
    -H "X-Auth-Key: ${cfSecret}" \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: ${cfLogin}" -o ${TEMP_DIR}/zone.json
}

function cfGetZoneId
{
    cfDomain=$1
    jq -r '.result[]|select(.name=="'${cfDomain}'")|.id' \
    $TEMP_DIR/zone.json
}

function cfGetRecords
{
    cfZoneId=$1
    curl -sX GET "https://api.cloudflare.com/client/v4/zones/${cfZoneId}/dns_records?type=A" \
        -H "X-Auth-Email: ${cfLogin}" \
        -H "X-Auth-Key: ${cfSecret}" \
        -H "Content-Type: application/json" \
        -o $TEMP_DIR/records.json
}

function cfGetRecordId
{
    local recName=$1
    jq -r ".result|.[]|select(.name == \"${recName}.${cfDomain}\")|.id" $TEMP_DIR/records.json
}

function cfPushRecord
{
    local cfZoneId=$1
    local cfRecordId=$2
    local recName=$3
    local recVal=$4

    curl -sX "PUT" "https://api.cloudflare.com/client/v4/zones/${cfZoneId}/dns_records/${cfRecordId}" \
        -H "X-Auth-Key: ${cfSecret}" \
        -H "Content-Type: application/json" \
        -H "X-Auth-Email: ${cfLogin}" \
        -d "{\"type\":\"A\",\"name\":\"$recName\",\"content\":\"$recVal\",\"proxied\":false,\"ttl\":120}" \
        -o $TEMP_DIR/result.json 

}
function cleanUp
{
    rm -rf ${TEMP_DIR}
}

# int main(){ ... }
# compare first IP
sampleIpAddr=$(snmpGetIP ${mkHostIp} ${mkSnmpCommunity} ${mkSnmpIfId[0]})
if [ -e $STATUS_FILE ] && [[ $(head -1 $STATUS_FILE) == ${sampleIpAddr} ]]; then
    echo "no need to update"
    exit 0
else
    # create and empty file or empty an file
    truncate -s 0 $STATUS_FILE
fi

cfGetZone
zoneId=$(cfGetZoneId ${cfDomain})
cfGetRecords ${zoneId}
for i in $(seq ${#cfRecordNames[*]}); do
    thisRecId=$(cfGetRecordId ${cfRecordNames[i-1]})
    thisIpAddr=$(snmpGetIP ${mkHostIp} ${mkSnmpCommunity} ${mkSnmpIfId[i-1]})
    thisFqdn=${cfRecordNames[i-1]}\.${cfDomain};
    cfPushRecord ${zoneId} ${thisRecId} ${cfRecordNames[i-1]} ${thisIpAddr}
    echo ${thisIpAddr} | tee -a $STATUS_FILE
done
cleanUp
