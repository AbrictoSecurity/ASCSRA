[![Abricto Security](https://abricto-static.s3.amazonaws.com/AbrictoSecurityVerticalBlackNotCropped.png")](https://abrictosecurity.com)

# Abricto Security Cloud Security Reporting and Automation

This repository houses the scripts, code, policies, and templates required for ASCSRA to work.

## AWS Deployment Guide

1. In IAM, create the ASCSRA-Default-Policy using the ASCSRA-Default-Policy.json file.
1. Create the ASCSRA role for the EC2 instance, attach the policy we just created to it, as well as the AWS-managed "AmazonSSMManagedInstanceCore" and "SecurityAudit" policies.
1. In EC2, provision a single EC2 Amazon Linux 2 AMI t3.micro instance, attach the ASCSRA role to it.
    1. Add a "Name" tag and call it ASCSRA.
    1. Enable encryption on the root volume.
    1. Name the security group ASCSRA and disable all inbound network access.
1. Create our ASCSRA-Admin user.
    1. Provide only programmatic access.
    1. Store access key and secret access key in LastPass Enterprise.
    1. Create a profile in your ~/.aws/credentials file.
        1. Optionally, create a config for the profile in ~/.aws/config
        1. Optionally, export your profile in bash: `export AWS_PROFILE=acmeprofile`
1. Back in IAM create the ASCSRA-SSM-SessionManager policy using the ASCSRA-SSM-SessionManager.json file.
    1. Replace the three fields between the triple-percentages with the appropriate values.
    1. Attach the policy to our ASCSRA-Admin user.
1. Connect to the EC2 instance: `aws ssm start-session --target i-0fddebe1ba54d5ac5`
1. Change user to be root: `sudo -i`
1. Install git: `yum install git`
1. Change user to be ec2-user: `su ec2-user`
1. Change into the ec2-user's home directory: `cd ~/`
1. Create an SSH key pair to pull down ASCSRA (replace acme with client): `ssh-keygen -t rsa -b 4096 -C "acme@abrictosecurity.com"`
1. Check to make sure the ssh-agent is running: `eval "$(ssh-agent -s)"`
1. Add the SSH key into the ssh-agent: `ssh-add ~/.ssh/id_rsa`
1. Add the public key into Github, then verify connectivity with: `ssh -T git@github.com`
1. Pull down ASCSRA: `git clone git@github.com:cjdupreez/ASCSRA.git`
1. Edit the recipient email address:
    1. `nano ./ASCSRA/ASCSRA-Emails/destination.json`
    1. `nano ./ASCSRA/ASCSRA-Emails/ASCSRA-Email-Report-Template.json`
1. Update the IgnoredChecks.csv and RemediateChecks.csv files to alert and remediate as needed.
1. Make sure in SES the recipient's address is verified.
1. Clone cloudsploit scans: `git clone https://github.com/cloudsploit/scans.git`
    1. Create the config file `cp config_example.js config.js`
    1. Uncomment the AWS hardcoded keys section in the config.js file, but leave the values empty.
    1. Install NodeJS:
        1. `sudo yum install -y gcc-c++ make`
        1. `curl -sL https://rpm.nodesource.com/setup_12.x | sudo -E bash -`
        1. `sudo yum install -y nodejs`
    1. Inside the `scans` directory, run: `npm install`
    1. Make the scanner executable: `chmod +x index.js`
1. Back in the ec2-user's home directory, clone the remediation guides: `git clone git@github.com:AbrictoSecurity/CSPM-Remediation-Guides.git`
1. Run `aws configure` just to specify the region as `us-east-1` or the appropriate region.
1. In SES, make sure the info@abrictosecurity.com email address is validated to be sent from.
1. Install the cronjobs as follows:
```
*/5 * * * *     /home/ec2-user/ASCSRA/ASCSRA.sh
0 0 * * *       /home/ec2-user/ASCSRA/ASCSRA-Report.sh Daily
0 0 * * 0       /home/ec2-user/ASCSRA/ASCSRA-Report.sh Weekly
0 0 1 * *       /home/ec2-user/ASCSRA/ASCSRA-Report.sh Monthly
```
