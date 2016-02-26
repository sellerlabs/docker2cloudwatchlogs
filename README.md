# Overview
This repository is based on the [blog post on using Amazon ECS and Amazon CloudWatch logs] (http://blogs.aws.amazon.com/application-management/post/TxFRDMTMILAA8X/Send-ECS-Container-Logs-to-CloudWatch-Logs-for-Centralized-Monitoring), with an attempt to make the config more flexible.

You can use Amazon CloudWatch to monitor and troubleshoot your systems and applications using your existing system, application, and custom log files. You can send your existing log files to CloudWatch Logs and monitor these logs in near real-time.

The directions below configure a syslog server on each host.  While I think you could probably just configure containers to syslog to 172.17.42.1 (default docker0 interface IP on the host), that's not what I'm describing, nor have I tested it.  Mainly, configuring a port mapping below is for ensuring that only one docker2cloudwatchlogs container runs on a given intance.  I am describing the use of volumes and the docker syslog log driver to avail host and docker logs to the cloudwatch logs agent.

##How To Search For ECS log events
Container output sent to /dev/stdout and /dev/stderr goes to the docker logs.  By default, using the Amazon ECS AMI, if you set your task container to use "syslog", logs will show up in /var/log/messages, where they can be picked up by the docker2cloudwatchlogs container.  After configuring containers to use "syslog", be aware that the traditional "docker logs" command will not work on those containers anymore.

Once logs are flowing into Cloudwatch Logs, you can echo unique event identiers or at least consitent event names to stderr/stdout.  Search for that identifier in cloudwatch logs.  Once you find that identifier, you've identified the docker instance ID -- the number appended to "docker/".  Here's an example log line:

```Jan 20 20:51:57 ip-172-31-33-54 docker/17d22acce791[2368]: #6 /var/www/scope/vendor/laravel/framework/src/Illuminate/Container/Container.php(633): Illuminate\Container\Container->build()```

The docker instance ID above is "17d22acce791".  Searching for "17d22acce791" will show only logs from that container.  Using the cloudwatch log configuration variables "{instance_id}", "{hostname}", and "{ip_address}", you can split the logs from multiple hosts into various streams.  But, even with use of the variables, logs from the multiple containers on a host would still be mingled into one stream.  And, I prefer searching one big log rather than one log per host.  So, I advocate throwing all the docker logs for a cluster into one place.  In my case, I do recommend having one log group per cluster, or at least per project.

##Configuration for Sending Docker Logs to Cloudwatch
###Instance IAM Roles
Be sure that an IAM role is associated with the cluster container instances (hosts) and that the role has an associated policy similar to this:
```{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}
```
###Create A Task
Use these attributes.

* image: quay.io/sellerlabs/docker2cloudwatchlogs
* memory: 64
* environment variables (see below): at least set LOG_GROUP_NAME
* port mappings (make at least 1 mapping on some port so that you don't end up with more than one container on a given host; however, you don' tnecessarily have to listen on port 514, since this example will just use volumes to access the logs)
** for syslog TCP
*** host port: 514
*** container port: 514
*** protocol: tcp
** for syslog UDP
*** host port: 514
*** container port: 514
*** protocol: udp
* volume
** name: ecs_instance_logs
** source path: /var/log
* mount point
** container path: /mnt/ecs_instance_logs
** source volume: ecs_instance_logs
** read only: true
###Create A Service
Use the task definition above.  Set the desired count equal to the number of hosts that you have in the cluster.  Set "minimum healthy percent" to 0 and "maximum" percent" to 100.
###Configure Container Log Driver
For all container definitions in all services in the cluster, use the "syslog" log driver.  Otherwise, container logs will only be available by logging into each host and running "docker logs".

## Environment Variables
Takes up to 3 environment variables.  If you don't set AWS_LOGS_CONF_URL, you will at least want to set LOG_GROUP_NAME.

* AWS_REGION: Will direct logs to the given region; efault is us-east-1
* AWS_LOGS_CONF_URL: Will slurp in an entire aws cloudwatch logs config file
* LOG_STREAM_NAME_PREFIX: a prefix on cloudwatch log stream destinations
* LOG_GROUP_NAME: which log group will this log to

The following variables may be used in the cloudwatch logs agent config file or in LOG_STREAM_NAME_PREFIX:

* {instance_id}
* {hostname}
* {ip_address}
