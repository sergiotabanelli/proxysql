<?php
$usid = getenv('c19_usid', TRUE);
$pport = getenv('c19_pport', TRUE);
$mysqli = new mysqli('127.0.0.1', 'root#pippo' . $usid, 'password', 'test', $pport . '6033');
if ($mysqli->connect_error) {
    die('Connect Error (' . $mysqli->connect_errno . ') '
            . $mysqli->connect_error);
}
