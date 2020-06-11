<?php
require_once('tinc.php');
$iter = 5;
$mysqli->begin_transaction();
for ($i=0; $i<$iter; $i++)
{
    $mysqli->query("INSERT INTO test VALUES (NULL, uuid(), now(), $i)");
    $id = $mysqli->insert_id;
    $result  = $mysqli->query("SELECT COUNT(*) AS 'count', @@gtid_executed AS 'gtid_executed', @@server_id AS 'server_id' FROM test WHERE i = $id");
    if ($result->num_rows != 1) {
        echo "Error! Dirty read for $i id is $id\n";
        var_dump($result->fetch_row());
        break;
    } 
}
$mysqli->commit();

for ($i=0; $i<$iter; $i++)
{
    $mysqli->query("INSERT INTO test VALUES (NULL, uuid(), now(), $i)");
    $id = $mysqli->insert_id;
    $result  = $mysqli->query("SELECT COUNT(*) AS 'count', @@gtid_executed AS 'gtid_executed', @@server_id AS 'server_id' FROM test WHERE i = $id");
    if ($result->num_rows != 1) {
        echo "Error! Dirty read for $i id is $id\n";
        var_dump($result->fetch_row());
        break;
    } 
}

$mysqli->close();
