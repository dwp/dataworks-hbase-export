#!/bin/bash

TABLE_NAME=$1
EXPORT_LOCATION=$2

DATE=`date +"%Y%m%d"`
VALID_SNAPSHOT_NAME_REGEX='^-.a-zA-Z_0-9'

function sanitise_table_name() {
    # replace spaces with underscores
    SANITISED_TABLE_NAME=${TABLE_NAME// /_}
    # replace colons with fullstops
    SANITISED_TABLE_NAME=${SANITISED_TABLE_NAME//:/.}
    # clean out anything that's not valid
    SANITISED_TABLE_NAME=${SANITISED_TABLE_NAME//[$VALID_SNAPSHOT_NAME_REGEX]/}
    # lowercase
    SANITISED_TABLE_NAME=`echo -n $SANITISED_TABLE_NAME | tr A-Z a-z`
    # append date
    SANITISED_TABLE_NAME="${SANITISED_TABLE_NAME}_${DATE}"
    echo $SANITISED_TABLE_NAME
}

function valid_snapshot_name() {
    SNAPSHOT_NAME=$1
    if ! [[ "$SNAPSHOT_NAME" =~ [$VALID_SNAPSHOT_NAME_REGEX] ]]; then
        return 0
    else
        return 1
    fi
}

function get_snapshot() {
    # Verify snapshot was created (retry logic maybe required)
    hbase snapshot info -list-snapshots | grep ${SNAPSHOT_NAME}
    if [ $? != 0 ]; then
        echo "could not find snapshot with name ${SNAPSHOT_NAME}"
        return 1
    else
        return 0
    fi
}

function take_snapshot() {
    if get_snapshot; then
        echo "snapshot with name ${SNAPSHOT_NAME} already exists. exiting..."
        exit 1
    fi

    echo "taking snapshot of table ${TABLE_NAME}"
    hbase snapshot create -n ${SNAPSHOT_NAME} -t ${TABLE_NAME}
    if [ $? != 0 ]; then
        echo "snapshot creation failed. exiting..."
        exit 1
    fi
}

function export_snapshot() {
    echo "exporting snapshot ${SNAPSHOT_NAME} to ${EXPORT_LOCATION}"
    hbase snapshot export -snapshot ${SNAPSHOT_NAME} -copy-to $EXPORT_LOCATION
    if [ $? != 0 ]; then
        echo "export failed. exiting..."
        exit 1
    else
        echo "export finished"
    fi
}

if [ -z $SNAPSHOT_NAME ]; then
    echo "No snapsnot name provided. Sanitising table name ${TABLE_NAME}"
    SNAPSHOT_NAME=$(sanitise_table_name $TABLE_NAME)
    echo "New snapshot name will be: ${SNAPSHOT_NAME}"
fi

if ! valid_snapshot_name $SNAPSHOT_NAME; then 
    echo "invalid snapshot name: ${SNAPSHOT_NAME}"
fi

take_snapshot
export_snapshot
