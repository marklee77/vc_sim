#!/bin/bash
LINETYPES=(1 2 3 4 5 7 8 10 11 12 13)
MYSQL="mysql hpcdata2 --batch --skip-column-names"
OUTDIR="$1"
ALGOS=$(cat <<EOF
fcfs
easy
greedy_activeres_opttarget:maxminyield
greedy-pmtn-migr_activeres_opttarget:maxminyield
greedy-pmtn-migr_opttarget:maxminyield_per:600
greedy-pmtn-migr_activeres_opttarget:maxminyield_per:600
mcb8_activeres_opttarget:maxminyield_per:600
opttarget:maxminyield_per:600
stretch_opttarget:minmaxstretch_per:600
greedy-pmtn-migr_activeres_opttarget:maxminyield_per:600_minvt:600
mcb8_activeres_opttarget:maxminyield_per:600_minvt:600
EOF
)

SQLALGOLIST=""
for ALGO in ${ALGOS}; do
    if [ -z "${SQLALGOLIST}" ]; then
        SQLALGOLIST="'${ALGO}'"
    else
        SQLALGOLIST="'${ALGO}', ${SQLALGOLIST}"
    fi
done

if [ -z "${OUTDIR}" -o -e "${OUTDIR}" ]; then
    echo "must give a new directory name as parameter!"
    exit 1
fi

mkdir -p ${OUTDIR}
cd ${OUTDIR}

(
echo "set xrange [0.1:0.9]"
echo "set logscale y"
echo "set key on outside center bottom horizontal box width +1"
echo "set xlabel \"Load\""
echo "set term postscript eps color"
#echo "set term png"
EXT="eps"

DATASETS=$(${MYSQL} -e "select distinct dataset from problems where dataset like '%scaled%' order by dataset;")
for DATASET in ${DATASETS}; do
    DELAYS=$(${MYSQL} -e "select distinct delay from solutions where dataset = '${DATASET}' order by delay;")
    for DELAY in ${DELAYS}; do

        STRETCHDIR="${DATASET}/${DELAY}/stretch"
        mkdir -p ${STRETCHDIR}

        DFBOUNDDIR="${DATASET}/${DELAY}/deg-from-bound"
        mkdir -p ${DFBOUNDDIR}

        DFBESTDIR="${DATASET}/${DELAY}/deg-from-best"
        mkdir -p ${DFBESTDIR}

        if [ -z "${ALGOS}" ]; then
            ALGOS=$(${MYSQL} -e "select distinct algo from solutions where dataset = '${DATASET}' and delay = ${DELAY} order by algo;")
        fi

        for ALGO in ${ALGOS}; do 

${MYSQL} > ${STRETCHDIR}/${ALGO}.dat <<EOF
    select format(sload / 10, 1), avg(avgstretch), avg(maxstretch)
    from problems, solutions
    where problems.dataset = solutions.dataset and problems.trace = solutions.trace
      and problems.dataset = '${DATASET}' and solutions.delay = ${DELAY} and solutions.algo = '${ALGO}'
    group by sload;
EOF

${MYSQL} > ${DFBOUNDDIR}/${ALGO}.dat <<EOF
    select format(sload / 10, 1), avg(maxstretch / msbound), max(maxstretch / msbound)
    from problems, solutions
    where problems.dataset = solutions.dataset and problems.trace = solutions.trace
      and problems.dataset = '${DATASET}' and solutions.delay = ${DELAY} and solutions.algo = '${ALGO}'
    group by sload;
EOF

${MYSQL} > ${DFBESTDIR}/${ALGO}.dat <<EOF
    select format(sload / 10, 1), avg(avgstretch / minavgstretch), avg(maxstretch / minmaxstretch)
    from problems, solutions, (
        select dataset, delay, trace, min(avgstretch) as minavgstretch, min(maxstretch) as minmaxstretch
          from solutions
         where algo in (${SQLALGOLIST})
        group by dataset, delay, trace) as best
    where problems.dataset = solutions.dataset
      and problems.trace = solutions.trace
      and problems.dataset = best.dataset and solutions.delay = best.delay 
      and problems.trace = best.trace
      and problems.dataset = '${DATASET}' and solutions.delay = ${DELAY} and algo = '${ALGO}'
    group by sload;
EOF
        done

        echo "set ylabel \"Stretch\""
        echo "set yrange [1:100000]"

        echo "set title \"Average Stretch vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"avgs-vs-load-${DELAY}-delay.${EXT}\""
        FILES=($(ls ${STRETCHDIR}/*.dat))
        echo -n "plot "
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:2 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        echo "set title \"Maximum Stretch vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"maxs-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${STRETCHDIR}/*.dat))
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:3 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        echo "set ylabel \"Maxstretch degradation From Bound\""
        echo "set yrange [1:10000]"

        echo "set title \"Maximum degradation From Bound vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"maxsdfbound-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${DFBOUNDDIR}/*.dat))
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:2 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        echo "set yrange [1:10000]"

        echo "set ylabel \"Average Stretch degradation From Best\""
        echo "set title \"Average Stretch degradation Factor vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"avgsdfbest-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${DFBESTDIR}/*.dat))
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:2 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo

        echo "set ylabel \"Maximum Stretch degradation From Best\""
        echo "set title \"Maximum Stretch degradation Factor vs. System Load, ${DELAY} second restart penalty.\""
        echo "set output \"maxsdfbest-vs-load-${DELAY}-delay.${EXT}\""
        echo -n "plot "
        FILES=($(ls ${DFBESTDIR}/*.dat))
        LASTFILE=${FILES[${#FILES[@]}-1]}
        LINETYPEIDX="0"
        for FILE in "${FILES[@]}"; do
            SCHEDNAME=$(basename ${FILE} .dat | tr "a-z_" "A-Z ")
            LINETYPE=${LINETYPES[${LINETYPEIDX}]}
            LINETYPEIDX=$((${LINETYPEIDX}+1))
            echo -n "\"${FILE}\" using 1:3 with linespoints title \"${SCHEDNAME/ 0/}\" lt ${LINETYPE} lw 2"
            if [ ${FILE} != ${LASTFILE} ]; then
              echo ",\\"
            fi  
        done
        echo
    done
done

) > graphs.plt
