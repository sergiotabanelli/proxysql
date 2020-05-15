<?php
date_default_timezone_set('UTC');
$mysqli = new mysqli('127.0.0.1', 'root#pippo1', 'password', 'test', 6033);
if ($mysqli->connect_error) {
    die('Connect Error (' . $mysqli->connect_errno . ') '
            . $mysqli->connect_error);
}
echo date('Y-m-d H:i:s') . " Starting to SETUP the test\n";
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
