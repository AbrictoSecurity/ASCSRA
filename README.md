# Abricto Security Cloud Security Reporting and Automation (ASCSRA)

ASCSRA allows organizations to monitor their AWS cloud environment in near real-time for security vulnerabilities or misconfigurations. When a new vulnerability gets detected, an email alert instantly gets sent out . A nightly report also gets emailed out which highlights and details all the alerts within the past 24 hours.

By default, the AWS environment is interrogated every 10 minutes. The results of that interrogation are compared against the previous interrogation's results and new security alerts are distributed via email. Noisy alerts can be silenced by modifying the IgnoreAlerts.csv file either by category (e.g. all S3 buckets with missing encryption in-transit), or by resource (e.g. a specific S3 bucket with missing encryption in-transit).

This project is only possible because of all the hard work done by the [CloudSploit](https://github.com/aquasecurity/cloudsploit) team and its community.

## AWS Deployment Guide

1. In IAM, create the ASCSRA-Default-Policy using the ASCSRA-Policies/ASCSRA-Default-Policy.json file.
1. Create the ASCSRA user with only programmatic access and attach the policy we just created to it, as well as the "SecurityAudit" policy.
1. Create a role for our EC2 instance called ASCSRA-EC2 and attach the AWS-managed "AmazonSSMManagedInstanceCore" policy to it.
1. In EC2, provision a single EC2 Amazon Linux 2 AMI t3.micro instance, attach the ASCSRA-EC2 role to it.
    1. Provision at least 30 GiB of root volume storage.
    1. Enable encryption on the root volume.
    1. Add a "Name" tag and call it ASCSRA.
    1. Name the security group ASCSRA and disable all inbound network access.
1. Back in IAM create the ASCSRA-SSM-SessionManager policy using the ASCSRA-Policies/ASCSRA-SSM-SessionManager.json file.
    1. Replace the %%%instance-id%%% on line 10 with the appropriate instance ID of the ASCSRA EC2 instance.
1. Now, create our ASCSRA-Admin user.
    1. Provide only programmatic access.
    1. Attach the ASCSRA-SSM-SessionManager policy directly to this user.
    1. Create a named profile for your ascsra-admin user: `aws configure --profile ascsra-admin`
        1. Optionally, export your profile in bash: `export AWS_PROFILE=ascsra-admin`
1. Now, specify your instance ID and connect to the EC2 instance: `aws ssm start-session --target i-0fddebe1ba54d5ac5 --profile ascsra-admin`
1. Change user to ec2-user: `sudo su ec2-user -l`
1. Install git and docker: `sudo yum install git docker -y && sudo service docker start && sudo chkconfig docker on && sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/bin/docker-compose && sudo chmod +x /usr/bin/docker-compose`
1. Pull down ASCSRA: `git clone https://github.com/AbrictoSecurity/ASCSRA.git`
1. Edit the sender and recipient email addresses:
    1. `nano ASCSRA/api/templates/reports/ASCSRA-Email-Report-Template.json`
    1. `nano ASCSRA/docker-compose.yml`
1. Insert the ASCSRA user's AWS_SECRET_ACCESS_KEY and AWS_ACCESS_KEY_ID values into the docker-compose file: `nano ASCSRA/docker-compose.yml`
1. Update the IgnoreAlerts.csv file to silence alerts as needed.
    1. `nano ASCSRA/config/IgnoreAlerts.csv`
1. In SES:
    1. Make sure both the sender and the recipient's email addresses are validated.
1. Run `aws configure` to specify the region as `us-east-1` or the appropriate region, other fields can be left as "None".
1. Launch the docker containers with: `sudo docker-compose -f ~/ASCSRA/docker-compose.yml up -d`

## Contributing

We welcome bug fixes, feature requests and other contributions to the ASCSRA project. Please see our [issues page](https://github.com/AbrictoSecurity/ASCSRA/issues) for active issues before submitting a pull request.
