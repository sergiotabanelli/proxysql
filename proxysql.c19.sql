INSERT INTO "mysql_servers" VALUES(1,'mysql1',3306,6020,'ONLINE',1,0,1000,0,0,0,'');
INSERT INTO "mysql_servers" VALUES(1,'mysql2',3306,6020,'ONLINE',1,0,1000,0,0,0,'');
INSERT INTO "mysql_servers" VALUES(1,'mysql3',3306,6020,'ONLINE',1,0,1000,0,0,0,'');
INSERT INTO "memcached_hostgroups" VALUES(1,'--SERVER=memcached --POOL-MIN=10 --POOL-MAX=100',20,'#S','#U',0,1,NULL);
INSERT INTO "mysql_query_rules" VALUES(1,1,NULL,NULL,0,NULL,NULL,NULL,NULL,'^SELECT',NULL,0,'CASELESS',NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,1,NULL,1,NULL);
/*
INSERT INTO "mysql_query_rules" VALUES(2,1,NULL,NULL,0,NULL,NULL,NULL,NULL,'^INSERT',NULL,0,'CASELESS',NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,2,1,NULL,1,NULL);
*/
INSERT INTO "mysql_users" VALUES('root','password',1,0,1,NULL,0,1,0,1,1,10000,'');
SET mysql-monitor_username = 'root';
SET mysql-monitor_password = 'password';
SET mysql-auto_increment_delay_multiplex = 0;
LOAD MYSQL VARIABLES TO RUNTIME;
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;

