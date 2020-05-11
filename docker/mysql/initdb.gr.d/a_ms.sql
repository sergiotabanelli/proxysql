CREATE DATABASE IF NOT EXISTS test;
CREATE TABLE IF NOT EXISTS `test`.`test` (
  `i` bigint(11) NOT NULL AUTO_INCREMENT,
  `s` char(255) DEFAULT NULL,
  `t` datetime NOT NULL,
  `g` bigint(11) NOT NULL,
  KEY(`i`, `t`),
  PRIMARY KEY(`i`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;
create user 'repl'@'%';
GRANT REPLICATION SLAVE ON *.* TO repl@'%';
GRANT BACKUP_ADMIN ON *.* TO repl@'%';
flush privileges;
change master to master_user='repl' for channel 'group_replication_recovery';
