# ProxySQL C19 Patch: Multi-master read/write consistency enforcing in MySQL asynchronous clusters 
>NOTE: This patch require [MySQL >= 5.7.6 with --session-track-gtids=OWN_GTID](https://dev.mysql.com/doc/refman//8.0/en/server-system-variables.html#sysvar_session_track_gtids) and at least one memcached protocol capable server, eg [memcached](https://memcached.org/), [couchbase](https://www.couchbase.com/) or also [mysql with the memcached plugin](https://dev.mysql.com/doc/refman/8.0/en/innodb-memcached-setup.html).

>BEWARE: Right now this is still only a working POC, not more!

>NOTE: Here is the original [README.md](./README.orig.md) from ProxySQL

The Idea for this patch was born in 2019 when we start thinking a convenient method to extend, to languages other than PHP, the MySQL Consistency enforcement policy implemented in our [mymysqlnd_ms](https://github.com/sergiotabanelli/mysqlnd_ms/) fork, hence, from `Consistency` and `2019`, the name `C19`. Furthermore, during Covid 19 lock down and forced quarantine this first POC has been implemented, hence, from `Covid 19`, the name `C19`. Below a short rationale and getting started.

Different types of MySQL cluster solutions offer different service and data consistency levels to their users. Any asynchronous MySQL replication cluster offers eventual consistency by default. A read executed on an asynchronous slave may return current, stale or no data at all, depending on whether the slave has replayed all changesets from master or not.
Applications using a MySQL replication cluster need to be designed to work correctly with eventual consistent data. In most cases, however, stale data is not acceptable. In those cases only certain slaves or even only master are allowed to achieve the required quality of service from the cluster.

New MySQL functionalities available in more recent versions, like [multi source replication](https://dev.mysql.com/doc/refman/5.7/en/replication-multi-source.html) or [group replication](https://dev.mysql.com/doc/refman/5.7/en/group-replication.html), allow multi-master clusters and need application strategies to avoid write conflicts and enforce write consistency for distinct write context partitions.

The excellent [ProxySQL](https://proxysql.com) already has a [Consistent read feature](https://proxysql.com/blog/proxysql-gtid-causal-reads/) but it does not cross client connection boundaries and can't use consistency context partitions, that is: the consistency enforcement is limited to the current connection, but eg async web applications, where reads and writes are normaly on distinct http requests and, therefore, on distinct DB connectios, need a more complex read consistency enforcement policy. And also, `ProxySQL` does not have features for write conflicts management in multi-master asyncronous cluster scenarios. 
The `ProxySQL C19` patch adds these features to standard `ProxySQL` and can therefore transparently choose MySQL replication nodes according to the read and write requested consistency, and this also on distinct MySQL connections and also on connections spread across multiple `ProxySQL` instances. 

To share consistency enforcement context info, the C19 patch, use memcached. Memcached can be considered not a valid choice due to its non persistent character, indeed, if the C19 patch loose connection to the memcached servers or consistency context stored on memcached keys become unavailable, no consistency will be enforced. To partially mitigate this issue and justify the choice we could consider that:
* Memcached is extremely fast, really easy to setup and wildly known and used
* There are alternatives that support memcached communication protocol with various degree of persistency functionalities
* For consistent reads, sporadic enforcement failures due to memcached unavailability, can be considered acceptable
* For consistent writes in multi master InnoDB clusters (group replication), enforcement failures, will not lead to replication breaks but only to a transaction rollback
* For consistent writes in multi master multi source replication cluster, enforcement failures, can lead to replication breaks, for those cases a more robust memcached protocol capable server with persistency and HA functionalities like [couchbase](https://www.couchbase.com/) is suggested
* For future releases something like a fallback strategy could be implemented
* For future releases memcached can also be used as shared query cache, this also considering that read consistency can be considered a perfect cache invalidation strategy, that is: every time a write occurs for that partition context, all cached queries belonging to that context could be invalidated
* For future releases support for redis cache could be easily added

## Consistency context partitions
Context partitions are sets of queries made by groups of clients (from here on 'participants') which need to share with each others the same configured isolated consistency context. With read consistency, a consistency context participant will read all writes made by other participants, itself included. With write consistency, in multi-master clusters, writes from all consistency context participants will always do not conflicts each others. Context partitions size can range from single query sent by a single client (eventual consistency) to global unique context partition which include all queries sent by all clients. Eventual consistency can indeed be considered as the smallest context partition, where every single query from every single client is a context partition. In asyncronous or semisyncronous clusters, smaller context partitions means better load distribution and performance. In `ProxySQL C19` patch context partitions are established through the use of placeholders. Placeholders are reserved tokens used in configuration values of the `memcached_hostgroups` `ProxySQL C19` table. The placeholder token will be expanded to the corresponding value at connection init, allowing consistency context establishment on a connection attribute basis (for a complete list see below). 

## Read consistency
A read context partition is a set of application reads made by a context participant that must always at least run against previous writes made by all other context participants.  
Starting from MySQL 5.7.6 the MySQL server features the [session-track-gtids](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_session_track_gtids) system variable, which, if set, will allow a client to be aware of the unique Global Transaction Identifier ([GTID](https://dev.mysql.com/doc/refman/5.7/en/replication-gtids.html)) assigned by MySQL to an executed transaction. This extremely useful feature allow clients to enforce consistency also on an application context basis, that is: a web application user normally does not need to stay perfectly in sync with writes made by another user, if userA add a record and userB add another record, there is no problem if userA does not immediately see record inserted by userB but problems arise when userA does not see his record!

C19 read consistency has following rules: 
* Reads belonging to a context partition can safely run only on cluster nodes that have already replicated all previous same context partition writes. 
* Reads belonging to a context partition can safely run on cluster nodes that still have not replicated writes from all other contexts.

For read consistency the most common scenarios is context partitioning on HTTP user session id. With [mymysqlnd_ms](https://github.com/sergiotabanelli/mysqlnd_ms/) plugin, this can be easily achieved accessing the PHP internal session id, this because the plugin is an extension of the PHP language, but for ProxySQL there is no means to directly access an http application session id. The C19 patch use a simple hack to workaround this limitation at the cost of a small and simple web application change, the hack is that every MySQL user that connect to ProxySQL C19 can have a trailing session id identifying the session id and therefore the needed read consistency context, that is: suppose that the mysql user used by your web application is `SQLmyapp`, than you can append the session id to the MySQL user separated by `#`, eg in PHP

```
$sqluser = 'SQLmyapp' . '#' . session_id();
```
The C19 patch will then strip the session id part from the connected MySQL user and use it as read context partition identifier. 

Another method is to supply the session id in the query as a comment, eg 
```
$query = '/* c19_key=' . session_id() . '*/' . 'SELECT * FROM myrealquery';
```
This allow application users to always read them writes also if made in different connections and also if distributed on different application servers. Especially in async ajax scenarios, where reads and writes are often made on distinct http requests, user session partitioning is of great value and allow transparent migration to MySQL asyncronous clusters in almost all use cases with no or at most extremely small effort and application changes.   

## Write consistency
New MySQL functionalities like [multi source replication](https://dev.mysql.com/doc/refman/8.0/en/replication-multi-source.html) or [group replication](https://dev.mysql.com/doc/refman/8.0/en/group-replication.html) allow multi-master clusters and need application strategies to avoid write conflicts and enforce write consistency for distinct write context partitions. A write context partition is a set of application writes that, if run on distinct masters, can potentially conflict each others but that do not conflict with write sets from all other defined partitions. 

It is widely known that adding masters to MySQL clusters does not scale out and does not increase write performance, that is because all masters replicate the same amount of data, so write load will be repeated on every master. However, given that other masters do not have to do the same amount of processing that the original master had to do when it originally executed the transaction, they apply the changes faster, transactions are replicated in a format that is used to apply row transformations only, without having to re-execute transactions again. There are also much more to take into account for clusters configurations, in practice distinct write queries sent to distinct masters will almost always have better total throughput then the same group of queries sent to a single master (as an example see [an overview of the Group Replication performance](https://mysqlhighavailability.com/an-overview-of-the-group-replication-performance/) multi-master peak with flow-control disabled). So the major obstacles to achieve a certain degree of writes scale-out are write conflicts and replication lag. The idea behind `mymysqlnd_ms` write consistency implementation is to move replication lag and write conflicts management to the ProxySQL balancer, that can be considered a far more easier scale-out resource. To summarize the C19 patch write consistency implementation tries to put loads on easier scalable front ends with the objective to enhance response time on much harder scalable back ends.

For write consistency, scenarios strictly depend from your application requirements and can range from write context partitioning on MySQL user, the most common, to context partitioning on a user session basis as for the above explained read consistency.

>BEWARE: distinct write sets partitions must not intersect each others. eg if a write set include all writes to table A, no other write set partition should include writes to table A.

Server side write consistency has following rules: 
* Writes belonging to distinct context partitions can safely run concurrently on distinct MySQL masters without any data conflicts and replication issues.
* Writes belonging to the same context partition can safely run concurrently only on the same master. 
* Writes belonging to the same context partition can safely run **NON** concurrently (there are no still pending same context writes) on any masters that has already replicated all previous same context writes.

## A quick look

Clone the repository, go to the cloned directory, if you want, take a quick look at `my`, `myt`, `mytt`, `myttt`, `docker-compose.gr.yml` and `proxysql.c19.sql`

* the `my` script simply invoke mysql client with query passed as first parameter, user session id as second parameter and ProxySQL port prefixed with third parameter
* the `myt` run for first parameter times a group of query of 1 insert, one select of the previous insert, 2 updates that if executed in backgroung with another `myt` execution will conflicts each other. For every single query it invokes the `my` script
* the `mytt` runs second parameter background instances of the `myt` script each one against a distinct user session id
* the `myttt` runs third parameter background instances of the `mytt` script each one against a distinct ProxySQL instance 
* `docker-compose.gr.yml` runs 3 MySQL group replication nodes each one with ProxySQL binlog reader installed, 1 memcached instance and 2 ProxySQL with C19 patch instances 
* `proxysql.c19.sql` is the sql script used to initialize ProxySQL instance according to the `docker-compose.gr.yml` running context

run the docker-compose.gr.yml, wait some time until all the containers has finish the entrypoints startup, and then run:

```
mysql -u radmin -pradmin -h 127.0.0.1 -P16032 <proxysql.c19.sql
mysql -u radmin -pradmin -h 127.0.0.1 -P26032 <proxysql.c19.sql
```

And then run:

```
./myttt 50 5 2
```
you can change the first and second parameter but not third because `docker-compose.gr.yml` has only 2 instances of ProxySQL C19 patch

## Getting started

Right now, to build the C19 patch, You must clone the repository and run the ProxySQL build steps, all PRoxySQL standard Makefile targets should work, distribution package build targets included

Go to the directory where you cloned the repo (or unpacked the tarball) and run:

```
make
sudo make install
```
the patch add a new table named `memcached_hostgroups` to the main ProxySQL schema:

```
Admin>SHOW CREATE TABLE memcached_hostgroups\G
*************************** 1. row ***************************
       table: memcached_hostgroups
Create Table: CREATE TABLE memcached_hostgroups (
    hostgroup INT CHECK (hostgroup>=0) NOT NULL PRIMARY KEY,
    connection_string VARCHAR NOT NULL, depth INT NOT NULL DEFAULT 20 CHECK (depth>0),
    reader_key VARCHAR NOT NULL DEFAULT ('#S'),
    writer_key VARCHAR,
    ttl INT NOT NULL DEFAULT 3600,
    active INT CHECK (active IN (0,1)) NOT NULL DEFAULT 1,
    comment VARCHAR)
1 row in set (0,00 sec)

```
The most important fields are :

* `hostgroup`: this field hold the id of the hostgroup for witch the read and write consistency will be enforced 
* `connection_string`: this is the connection string used for memcached servers, format is described in [libmemcached](http://docs.libmemcached.org/libmemcached_configuration.html)
* `depth`: this is the max number of concurrent query You expect for the write partitioned context, default is 20 
* `reader_key`: this is the key that identify the read context partition, normally contains a placeholder (see below), default value is `#S` that is the placeholder for the user session id 
* `writer_key`: this is the key that identify the write context partition, normally contains a placeholder (see below), it is used only if the hostgroup is multi-master and normally will be set to `#U` that is the placeholder for the MySQL connected user
* `ttl`: this is the time to live for memcached keys, default is 3600 seconds

Let's now configure taking as example the multi-master InnoDB cluster and memcached server run by `docker-compose.gr.yml` 

Connect to the admin port:
```
mysql -u radmin -pradmin -h 127.0.0.1 -P16032
```

First we add cluster nodes all belonging to the same hostgroup, indeed this is a multi-master cluster, specifying also the gtid_port of the ProxySQL binlog reader installed on every cluster node:
```
Admin>INSERT INTO "mysql_servers"(hostgroup_id,hostname,port,gtid_port) VALUES(1,'mysql1',3306,6020);
Query OK, 1 row affected (0,03 sec)

Admin>INSERT INTO "mysql_servers"(hostgroup_id,hostname,port,gtid_port) VALUES(1,'mysql2',3306,6020);
Query OK, 1 row affected (0,00 sec)

Admin>INSERT INTO "mysql_servers"(hostgroup_id,hostname,port,gtid_port) VALUES(1,'mysql3',3306,6020);
Query OK, 1 row affected (0,00 sec)
```

Then we add a mecached_hostgroups record for hostgroup 1 that will enforce a read consistency partitioned by user session id and a write consistency partitioned by MySQL users
```
Admin>INSERT INTO "memcached_hostgroups"(hostgroup,connection_string,reader_key,writer_key) VALUES(1,'--SERVER=memcached --POOL-MIN=10 --POOL-MAX=100','#S','#U');
Query OK, 1 row affected (0,02 sec)
```

Then we add the user that for this example will be `root`, obviously do not use root in environment other than tests and examples containers
```
Admin>INSERT INTO "mysql_users"(username,password,default_hostgroup) VALUES('root','password',1);
Query OK, 1 row affected (0,02 sec)
```

Then we add the query rules, for this scenario we need only one, that will identify query that will need read consistency enforcement, all the others query will be assumed to need write consistency enforcement. As for standard ProxySQL the C19 patch identify read consistency query if it match a query rule with a valid `gtid_from_hostgroup` field, we also set `multiplex` to `2` because we don't want multiplex disabled for queries with `@` in the digest.
```
Admin>INSERT INTO mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,multiplex,gtid_from_hostgroup,apply) VALUES(1,1,'^SELECT',1,2,1,1);
Query OK, 1 row affected (0,05 sec)
```

We now load to runtime and we are done
```
Admin>LOAD MYSQL SERVERS TO RUNTIME;
Query OK, 0 rows affected (0,15 sec)

Admin>LOAD MYSQL USERS TO RUNTIME;
Query OK, 0 rows affected (0,00 sec)

Admin>LOAD MYSQL QUERY RULES TO RUNTIME;
Query OK, 0 rows affected (0,03 sec)
```

Repeat all the above also for the other instance of ProxySQL of the `docker-compose.gr.yml` using the other admin port:
```
mysql -u radmin -pradmin -h 127.0.0.1 -P26032
```

We can now create the test.test table using the root MySQL user postfixed with distinct session id separated by `#` eg for a dummy session id `pippo1`:
```
mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P16033 -e 'SHOW CREATE TABLE test.test\G'
mysql: [Warning] Using a password on the command line interface can be insecure.
*************************** 1. row ***************************
       Table: test
Create Table: CREATE TABLE `test` (
  `i` bigint NOT NULL AUTO_INCREMENT,
  `s` char(255) DEFAULT NULL,
  `t` datetime NOT NULL,
  `g` bigint NOT NULL,
  PRIMARY KEY (`i`),
  KEY `i` (`i`,`t`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8
```

And then use it (note that queries are sent to different instances of ProxySQL, indeed use different ports): 
```
id=$(mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P26033 -B -N -s -e "INSERT INTO test.test VALUES (NULL, uuid(), now(), 1);SELECT LAST_INSERT_ID()")
count=$(mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P16033 -B -N -s -e "SELECT COUNT(*) FROM test.test WHERE i = $id")
if [[ ${count::1} == "1" ]]; then
    echo "OK $id"
else
    echo "ERROR! FOR ID $id"
fi
```
We can also mix queries with the same MySQL root user but different dummy user session id `pippo2`: 
```
id1=$(mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P26033 -B -N -s -e "INSERT INTO test.test VALUES (NULL, uuid(), now(), 1);SELECT LAST_INSERT_ID()")
id2=$(mysql -u root#pippo2 -ppassword -h 127.0.0.1 -P26033 -B -N -s -e "INSERT INTO test.test VALUES (NULL, uuid(), now(), 2);SELECT LAST_INSERT_ID()")
count=$(mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P16033 -B -N -s -e "SELECT COUNT(*) FROM test.test WHERE i = $id1")
if [[ ${count::1} == "1" ]]; then
    echo "From pippo1 $id1"
else
    echo "From pippo1 ERROR! read enforcement not working $id1"
fi
count=$(mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P26033 -B -N -s -e "SELECT COUNT(*) FROM test.test WHERE i = $id2")
if [[ ${count::1} == "1" ]]; then
    echo "From pippo1 the pippo2 insert has been replicated $id2"
else
    echo "From pippo1 the pippo2 insert has not been replicated $id2 but it is ok as well"
fi

count=$(mysql -u root#pippo2 -ppassword -h 127.0.0.1 -P16033 -B -N -s -e "SELECT COUNT(*) FROM test.test WHERE i = $id2")
if [[ ${count::1} == "1" ]]; then
    echo "From pippo2 $id2"
else
    echo "From pippo2 ERROR! read enforcement not working $id2"
fi
count=$(mysql -u root#pippo2 -ppassword -h 127.0.0.1 -P26033 -B -N -s -e "SELECT COUNT(*) FROM test.test WHERE i = $id1")
if [[ ${count::1} == "1" ]]; then
    echo "From pippo2 the pippo1 insert has been replicated $id1"
else
    echo "From pippo2 the pippo1 insert has not been replicated $id1 but it is ok as well"
fi
```

We can also run some conflicting updates
```
for i in {1..10}; do
mysql -u root#pippo2 -ppassword -h 127.0.0.1 -P16032 -B -N -s -e "UPDATE test.test SET g = g + 1 WHERE g = 1" &
mysql -u root#pippo1 -ppassword -h 127.0.0.1 -P26032 -B -N -s -e "UPDATE test.test SET g = g - 1 WHERE g = 2" &
done
```
## Placeholders

Here is the list of placeholders that can be used for the `reader_key` and `writer_key` fields of the `memcached_hostgroups` table:

* `#S` is for session id passed through the MySQL connected user eg in `root#pippo` `pippo` will be the session id
* `#U` is for the MySQL connected user eg in `root#pippo` `root` is the effective MySQL connection user
* `#D` is for the MySQL selected schema at connection time

## Status

>NOTE: This PATCH is in early development stage, if You find bugs or have any question open issue on github 

