#!/bin/bash

########################
# Simulator of Evolving SN P Systems using PLingua
#
# Parameter details:
# $1 = Input File
# $2 = Output File

. ./config.sh
. ./functions.sh

cleanPliFolders
cleanSimulationOutputFolder

start_time=`date "+%Y-%m-%d %H:%M:%S"`
echo "[$start_time] Starting Simulation of Evolving SN P using PLingua"

input_file="$1"
output_file="$2"

parseAndSimulateSNP "$input_file"
archiveInputFile "$input_file"
produceSpikeTrainOutput "$output_file"

end_time=`date "+%Y-%m-%d %H:%M:%S"`
echo "[$end_time] Done Simulating"
