#!/bin/sh

TYPE="$1"

if [ "${TYPE}" = "" ]; then
    TYPE="png"
fi
    
for DATASET in hpc2n-120 lubtraces-128 lubscaled-128; do
    for UBOUND in 60000; do
        ./make-periodic-graphs.sh ${TYPE} ${DATASET} ${UBOUND} -${DATASET}-to-${UBOUND}
    done
done

rename "s/000.${TYPE}/ksec.${TYPE}/" *.${TYPE}
