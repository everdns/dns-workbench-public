#!/bin/bash
set -e  # Exit on any command failure

HOSTS=(10.10.1.3)
RESOLVER_IP="10.10.1.1"
QUERY_RATES=(50000 100000 150000 200000 250000 300000 350000 400000 450000 500000 550000 600000)
RUNS_PER_QPS=10
SLEEP_BETWEEN_RUNS=30
COLLECTL_RUNTIME=64
DNSPERF_RUNTIME=$(( COLLECTL_RUNTIME - 4 ))
SLEEP_FOR_RUN=$(( COLLECTL_RUNTIME + 6 ))

NOW=$(date +"%Y%m%d-%H%M%S")
BASE_OUTDIR="results-${NOW}"

mkdir -p "$BASE_OUTDIR"

echo "Using output directory: $BASE_OUTDIR"

printf "%s\n" "$RESOLVER_IP" \
  | xargs -I{} ssh -oBatchMode=yes {} "mkdir -p ${BASE_OUTDIR}"

printf "%s\n" "${HOSTS[@]}" \
  | xargs -I{} ssh -oBatchMode=yes {} "mkdir -p ${BASE_OUTDIR}"

for Q in "${QUERY_RATES[@]}"; do
    QUAL="q${Q}"
    OUTDIR="${BASE_OUTDIR}/${QUAL}"
    mkdir -p "$OUTDIR"

    echo "==== Running test $QUAL ===="
    for (( i = 0; i < RUNS_PER_QPS; i++ )); do
        echo "==== Running test QPS:$QUAL Iteration $i ===="
        #Flush cache
        ssh -oBatchMode=yes "$RESOLVER_IP" "sudo rndc flushtree wi.lan"

        # -------------------------------------------------
        # Calculate absolute start times
        # -------------------------------------------------
        COLLECTL_START=$(date -d "+2 second" +%s)
        DNSPERF_START=$(( COLLECTL_START + 2 ))

        echo "collectl start epoch: $COLLECTL_START"
        echo "dnsperf  start epoch: $DNSPERF_START"

        # -------------------------------------------------
        # Start collectl at COLLECTL_START
        # -------------------------------------------------
        ssh -oBatchMode=yes "$RESOLVER_IP" "
        delay=\$(( $COLLECTL_START - \$(date +%s) ));
        (( delay > 0 )) && sleep \$delay
        nohup collectl -scndm --plot -c ${COLLECTL_RUNTIME} \
            > ${BASE_OUTDIR}/test_${QUAL}_${i} 2>&1 < /dev/null &
        " </dev/null >/dev/null 2>&1 &

        echo "scheduled collectl on resolver"

        # -------------------------------------------------
        # Start dnsperf exactly 1s after collectl
        # -------------------------------------------------
        DNSPERF_CMD="
            delay=\$(( $DNSPERF_START - \$(date +%s) ));
            (( delay > 0 )) && sleep \$delay
            exec nohup dnsperf-workbench \
                -s $RESOLVER_IP \
                -l ${DNSPERF_RUNTIME} \
                -d dnsperf_input \
                -c 32 \
                -T 32 \
                -Q ${Q} \
                -q 3000000 \
                > ${BASE_OUTDIR}/dnsperf_${QUAL}_${i} 2>&1
        "

        echo "scheduling dnsperf on test hosts"

        printf "%s\n" "${HOSTS[@]}" \
        | xargs -I{} -P4 ssh -n -f -oBatchMode=yes {} "$DNSPERF_CMD"

        echo "scheduled dnsperf on test hosts"

        # Allow test to complete
        sleep $SLEEP_FOR_RUN

        echo "copying files over"

        scp -oBatchMode=yes "$RESOLVER_IP:${BASE_OUTDIR}/test_${QUAL}_${i}*" "$OUTDIR/" 2>/dev/null

        j=1
        for host in "${HOSTS[@]}"; do
            scp -oBatchMode=yes \
                "$host:${BASE_OUTDIR}/dnsperf_${QUAL}_${i}*" \
                "$OUTDIR/dnsperf_${QUAL}_${i}_${j}" 2>/dev/null
            ((j++))
        done
        echo "Waiting $SLEEP_BETWEEN_RUNS"
        sleep $SLEEP_BETWEEN_RUNS
    done
    echo "==== Finished $QUAL ===="
done