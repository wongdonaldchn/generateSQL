#!/bin/bash

###############################################################################
#  Script name  : runAll.sh
#  Description  : as the name
#  Usage        : runAll.sh RUNNING_MODE AMPLIFICATION_FACTOR
#                     [RUNNING_MODE](Required)
#                       running mode(1: only generate sql files; 2: generate and run sql files)
#                     [AMPLIFICATION_FACTOR](Required)
#                       factor of amplification for base data
#  Returns      : 0   Normal End
#                    9  Abnormal End
###############################################################################
#get date string
DATE=`date "+%Y%m%d%H%M%S"`

#create log file
LOGFILE="./log/running_log_"${DATE}
touch ${LOGFILE}
echo "Generating log file, you can track the process by tailing log file:["${LOGFILE}"]"

#start statement
echo "Starting to run." >> ${LOGFILE}

#get parameters
echo "Ready to get parameters" >> ${LOGFILE}
PARAM_CNT=2
if [ ${#} -ne ${PARAM_CNT} ]; then
    echo "Failed. Parameters' count doesn't match. "${PARAM_CNT}" is needed. EXIT(9)" >> ${LOGFILE}
	echo "Failed. EXIT(9). Please see more details at log file:["${LOGFILE}"]"
    exit 9
fi

#Get running mode
ARG_MODE=${2}
echo "RUNNING MODE IS "${ARG_MODE} >> ${LOGFILE}

#Get amplification factor
ARG_AF=${1}
echo "AMPLIFICATION FACTOR IS "${ARG_AF} >> ${LOGFILE}

#Generate
echo "Generate SQL Files" >> ${LOGFILE}

echo '@sql/insertData.sql' > insert.sql