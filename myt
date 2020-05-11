#/bin/bash
set -f
SI=$2
if [ -z "$3" ]; then
    S=""
else
    S="$3"
fi
for ii in $(seq 1 $S); do
    for i in $(seq 1 $1); do
        id=$(./my "INSERT INTO test.test VALUES (NULL, uuid(), now(), $i);SELECT LAST_INSERT_ID()" "$SI" "$S")
        if [ -z "$id" ]; then
            echo "ERROR inserting row $i USER $SI INSTANCE $S"
            continue
        fi
        echo "Inserted row $i with id $id USER $SI INSTANCE $S"
        R=$(./my "SELECT COUNT(*), @@gtid_executed, @@server_id FROM test.test WHERE i = $id" "$SI" "$S")
        if [[ ${R::1} == "1" ]]; then
            echo "OK $i ID $id  INSTANCE $S"
        else
            echo "ERROR! $R FOR $i USER $SI ID $id  INSTANCE $S"
            break
        fi
        echo "Increment records with $i USER $SI  INSTANCE $S"
        ./my "UPDATE test.test SET g = g + 1 WHERE g = $i" "$SI" "$S"
        echo "Decrement records with $i USER $SI INSTANCE $S"
        ./my "UPDATE test.test SET g = g - 1 WHERE g = $i" "$SI" "$S"
    done
done