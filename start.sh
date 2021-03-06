#!/bin/sh
test -n "$AWS_LOGS_CONF_URL" &&  curl $AWS_LOGS_CONF_URL > /var/awslogs/etc/awslogs.conf
test -n "$AWS_REGION" && sed -i "s/us-east-1/$AWS_REGION/" /var/awslogs/etc/aws.conf
sed -i "s/LOG_STREAM_NAME_PREFIX/$LOG_STREAM_NAME_PREFIX/g" /var/awslogs/etc/awslogs.conf
sed -i "s/LOG_GROUP_NAME/$LOG_GROUP_NAME/g" /var/awslogs/etc/awslogs.conf
test -s "$AWS_REGION" && sed -i "s/us-east-1/$AWS_REGION/g" /var/awslogs/etc/aws.conf
/usr/local/bin/supervisord
