[![Abricto Security]("https://abricto-static.s3.amazonaws.com/AbrictoSecurityVerticalBlackNotCropped.png")](https://abrictosecurity.com)

# Abricto Security Cloud Security Reporting and Automation

This repository houses the scripts, code, policies, and templates required for ASCSRA to work.

## AWS Deployment Guide

1. In IAM, create the ASCSRA-Default-Policy using the ASCSRA-Policies/ASCSRA-Default-Policy.json file.
1. Create the ASCSRA role for the EC2 instance, attach the policy we just created to it, as well as the AWS-managed "AmazonSSMManagedInstanceCore" and "SecurityAudit" policies.
1. In EC2, provision a single EC2 Amazon Linux 2 AMI t3.micro instance, attach the ASCSRA role to it.
    1. Add a "Name" tag and call it ASCSRA.
    1. Enable encryption on the root volume.
    1. Name the security group ASCSRA and disable all inbound network access.
1. Create our ASCSRA-Admin user.
    1. Provide only programmatic access.
    1. Create a profile in your ~/.aws/credentials file.
        1. Optionally, create a config for the profile in ~/.aws/config called ascsraprofile
        1. Optionally, export your profile in bash: `export AWS_PROFILE=ascsraprofile`
1. Back in IAM create the ASCSRA-SSM-SessionManager policy using the ASCSRA-Policies/ASCSRA-SSM-SessionManager.json file.
    1. Replace the %%%instance-id%%% on line 10 with the appropriate instance ID of the ASCSRA EC2 instance.
    1. Attach the policy to our ASCSRA-Admin user.
1. Now, specify your instance ID and connect to the EC2 instance: `aws ssm start-session --target i-0fddebe1ba54d5ac5`
1. Install git: `sudo yum install git`
1. Pull down ASCSRA: `git clone https://github.com/AbrictoSecurity/ASCSRA.git`
1. Edit the sender and recipient email addresses:
    1. `nano api/templates/reports/ASCSRA-Email-Report-Template.json`
    1. `nano docker-compose.yml`
1. Insert the AWS_SECRET_ACCESS_KEY and AWS_ACCESS_KEY_ID values into the docker-compose file: `nano docker-compose.yml`
1. Update the config/IgnoredChecks.csv file to silence alerts as needed.
    1. `nano config/IgnoredChecks.csv`
1. In SES:
    1. Make sure the sender email address is validated to be sent from.
    1. Make sure in SES the recipient's address is verified to receive mail.
1. Run `aws configure` to specify the region as `us-east-1` or the appropriate region.
1. Launch the docker containers with: `sudo docker-compose -f ~/ASCSRA/docker-compose.yml up`
