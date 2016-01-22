#!/bin/sh
test -n "$AWS_LOGS_CONF" &&  wget -O /var/awslogs/etc/awslogs.conf $AWS_LOGS_CONF_URL
sed "s/LOG_STREAM_NAME_PREFIX/$LOG_STREAM_NAME_PREFIX/g" /var/awslogs/etc/awslogs.conf
sed "s/LOG_GROUP_NAME/$LOG_GROUP_NAME/g" /var/awslogs/etc/awslogs.conf
/usr/local/bin/supervisord
