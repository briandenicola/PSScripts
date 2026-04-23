#!/bin/bash

export PASSWORD=${1}
export EXPORT_DIR=${2:-~/working/cqrs}
export ACME_HOME=~/.acme.sh
export LOG_FILE=${EXPORT_DIR}/certs.log

URLs=(`acme.sh --list | awk 'NR > 1 {print $1}'`)

mkdir -p ${EXPORT_DIR}
touch ${LOG_FILE}

for url in "${URLs[@]}"; 
do 
    echo "[`date`] - Requesting Certificate for ${url} from Let's Encrypt" | tee -a ${LOG_FILE}
    ${ACME_HOME}/acme.sh --renew -d ${url} --force

    echo "[`date`] - Exporting Certificate ${url} to pfx format" | tee -a ${LOG_FILE}
    ${ACME_HOME}/acme.sh --toPkcs -d ${url} --password ${PASSWORD}

    SAFE_URL=`echo ${url} | sed s/\*/wildcard/g`
       
    if [ ! -d ${EXPORT_DIR}/${SAFE_URL} ]
    then
        mkdir -p ${EXPORT_DIR}/${SAFE_URL}
    fi

    expiration_date=`${ACME_HOME}/acme.sh --list -d ${url} | grep -i Le_NextRenewTimeStr | awk -F= '{print $2}'`
    echo "[`date`] - Expiration date for ${url} - ${expiration_date}" | tee -a ${LOG_FILE}

    echo "[`date`] - Coping files to ${SAFE_URL}" | tee -a ${LOG_FILE}
    cp ${ACME_HOME}/${url}_ecc/fullchain.cer ${EXPORT_DIR}/${SAFE_URL}/${SAFE_URL}.cer
    cp ${ACME_HOME}/${url}_ecc/${url}.key ${EXPORT_DIR}/${SAFE_URL}/${SAFE_URL}.key
    cp ${ACME_HOME}/${url}_ecc/${url}.pfx ${EXPORT_DIR}/${SAFE_URL}.pfx
done
