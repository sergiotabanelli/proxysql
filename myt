#/bin/bash
set -f
SI=$2
if [ -z "$3" ]; then
    S=""
else
    S="$3"
fi
#for ii in $(seq 1 $S); do
    for i in $(seq 1 $1); do
        id=$(./my "INSERT INTO test.test VALUES (NULL, @@server_id, now(), $i);SELECT LAST_INSERT_ID()" "$SI" "$S")
#        last=$(./my "INSERT INTO test.test VALUES (NULL, uuid(), now(), $i);SELECT LAST_INSERT_ID(), @@server_id" "$SI" "$S")
#        id="${last%[[:blank:]]*}"
        if [ -z "$id" ]; then
            echo "ERROR inserting row $i USER $SI INSTANCE $S"
            break
        fi
        echo "Inserted row $i with id $id USER $SI INFO $last INSTANCE $S"
        R=$(./my "SELECT COUNT(*), t.s FROM test.test AS t WHERE i = $id" "$SI" "$S")
        if [[ ${R::1} == "1" ]]; then
            echo "OK $i ID $id  INFO $R INSTANCE $S"
        else
            echo "ERROR! $R FOR $i USER $SI ID $id  INSTANCE $S"
        fi
        echo "Increment records with $i USER $SI  INSTANCE $S"
        ./my "UPDATE test.test SET g = g + 1 WHERE g = $i" "$SI" "$S"
        echo "Decrement records with $i USER $SI INSTANCE $S"
        ./my "UPDATE test.test SET g = g - 1 WHERE g = $i" "$SI" "$S"
    done
#done