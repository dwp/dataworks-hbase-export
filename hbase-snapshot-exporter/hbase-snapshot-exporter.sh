#!/bin/bash

DATE=`date +"%Y%m%d"`
TABLE_NAME=$1
EXPORT_LOCATION=$2

function sanitise_table_name() {
    TABLE_NAME=$1
    # replace spaces with underscores
    SANITISED_TABLE_NAME=${TABLE_NAME// /_}
    # replace colons with fullstops
    SANITISED_TABLE_NAME=${TABLE_NAME//:/.}
    # clean out anything that's not valid
    SANITISED_TABLE_NAME=${SANITISED_TABLE_NAME//[^.a-zA-Z0-9_]/}
    # lowercase
    SANITISED_TABLE_NAME=`echo -n $SANITISED_TABLE_NAME | tr A-Z a-z`
    # appenddate
    SANITISED_TABLE_NAME="${SANITISED_TABLE_NAME}_${DATE}"
    echo $SANITISED_TABLE_NAME
}

function valid_snapshot_name() {
    SNAPSHOT_NAME=$1
    regex='^-.a-zA-Z_0-9'
    if ! [[ "$SNAPSHOT_Name" =~ [$regex] ]]; then
        return 0
    else
        return 1
    fi
}

function export_snapshot() {
    EXPORT_LOCATION=$1
    echo "exporting snapshot ${SNAPSHOT_NAME} to ${EXPORT_LOCATION}"
    hbase snapshot export -snapshot ${SNAPSHOT_NAME} -copy-to $EXPORT_LOCATION
    if [ $? != 0 ]; then
        echo "export failed"
        exit 1
    else
        echo "export finished"
    fi
}

if [ -z $SNAPSHOT_NAME ]; then
    echo "No snapsnot name provided. Sanitising table name"
    SNAPSHOT_NAME=$(sanitise_table_name $TABLE_NAME)
    echo "New snapshot name will be: ${SNAPSHOT_NAME}"
fi

if ! valid_snapshot_name $SNAPSHOT_NAME; then 
    echo "invalid snapshot name: ${SNAPSHOT_NAME}"
fi

hbase snapshot create -n ${SNAPSHOT_NAME} -t ${TABLE_NAME}
hbase snapshot info -list-snapshots | grep ${SNAPSHOT_NAME}
export_snapshot $EXPORT_LOCATION
