FROM centos:7
LABEL Name=proxysqlc19
RUN yum update -y
RUN yum install -y epel-release \ 
        yum-utils
RUN yum --disablerepo=epel -y update ca-certificates
ADD ./binaries/proxysql-2.0.10.c19-1-centos7.x86_64.rpm /
RUN yum install -y /proxysql-2.0.10.c19-1-centos7.x86_64.rpm
RUN yum clean all
RUN sed -i 's/admin:admin/admin:admin;radmin:radmin/' /etc/proxysql.cnf
EXPOSE 6032 6033
ENTRYPOINT ["proxysql", "-f", "-D", "/var/lib/proxysql"]
