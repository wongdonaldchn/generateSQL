#!/bin/bash

###############################################################################
#  Script name  : generateSQL.sh
#  Description  : generate sql files by base data, amplify base data to specified volume.
#  Usage        : generateSQL.sh AMPLIFICATION_FACTOR
#                     [AMPLIFICATION_FACTOR](Required)
#                       factor of amplification for base data
#  Returns      : 0   Normal End
#                    9  Abnormal End
###############################################################################
#get date string
DATE=`date "+%Y%m%d%H%M%S"`

#start statement
echo "Generate SQL Files"

#get parameters
echo "Ready to get parameters" >> ${LOGFILE}

PARAM_CNT=1
if [ ${#} -ne ${PARAM_CNT} ]; then
    echo "Failed. Parameters' count doesn't match. "${PARAM_CNT}" is needed. EXIT(9)" >> ${LOGFILE}
	echo "Failed. EXIT(9). Please see more details at log file:["${LOGFILE}"]"
    exit 9
fi
#Get amplification factor
ARG_AF=${1}


#

echo '@sql/insertData.sql' > insert.sql