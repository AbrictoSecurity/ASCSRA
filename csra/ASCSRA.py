#! /usr/bin/env python3
import errno
import subprocess
import os
import time
import mysql.connector
import hashlib
import csv
from shutil import copyfile
from csv import reader

def main():
    global project
    starttime = time.time()
    while True:
        scan()
        # Scan once per hour to lessen queries against services and remain below free tier threshold.
        time.sleep(3600.0 - ((time.time() - starttime) % 3600.0))

def scan():
    seconds = time.time()
    now = time.ctime(seconds)
    epoch = str(int(seconds))
    print("[+] Starting Abricto Security Cloud Security Reporting and Automation (ASCSRA) scan at:", now)
    scanresults = "/tmp/AbrictoSecurityAlerts-" + epoch + ".csv"
    startscan = "cd ./scans && node index.js --ignore-ok --config ./config.js --console=none --csv=" + scanresults + " &> ../ASCSRA-ScanOutput.log && cd .."
    subprocess.call(startscan, shell=True)

    # Wait until results are published before moving on...
    while not os.path.exists(scanresults):
        time.sleep(1)
    while not os.path.getsize(scanresults) > 0:
        time.sleep(1)

    # Now that the file exists, and data is being (or was) written to it, let's wait 3 more seconds just to be sure the stream is finished.
    time.sleep(3)

    # Open the results, hash each line, then append it to the csv one line at a time. We'll use this hash to see what's changed.
    with open(scanresults, 'r') as lines:
        next(lines)
        filelines = []
        for line in lines:
            hashobject = hashlib.sha256(line.rstrip().encode())
            filelines.append(''.join([line.rstrip(), ',', hashobject.hexdigest(), '\n']))

    with open(scanresults, 'w') as lines:
        lines.writelines(filelines)

    saveresults(epoch)
    os.remove(scanresults)
    return;

def saveresults(epoch):
    # Setup database connection, create new table from template, insert results, close connection.
    ascspmdb = mysql.connector.connect(
    host = os.environ['MYSQL_HOSTNAME'],
    user = os.environ['MYSQL_USER'],
    password = os.environ['MYSQL_PASSWORD'],
    database = os.environ['MYSQL_DATABASE'],
    allow_local_infile = True,
    autocommit = True
    )

    mycursor = ascspmdb.cursor()
    newtable = "CREATE TABLE `AbrictoSecurityAlerts-{0}` LIKE scanResultsTemplate"
    mycursor.execute(newtable.format(epoch))

    insertresults = ("""LOAD DATA LOCAL INFILE '/tmp/AbrictoSecurityAlerts-{0}.csv'
    INTO TABLE `AbrictoSecurityAlerts-{1}`
    FIELDS TERMINATED BY ',' ENCLOSED BY '"'
    LINES TERMINATED BY '\n'
    IGNORE 1 ROWS
    (category,title,resource,region,statusWord,message,id)""")

    mycursor.execute(insertresults.format(epoch, epoch))
    ascspmdb.close()
    calculatediff(epoch)
    return;

def calculatediff(epoch):
    # Setup database connection, create new table from template, insert results, close connection.
    ascspmdb = mysql.connector.connect(
    host = os.environ['MYSQL_HOSTNAME'],
    user = os.environ['MYSQL_USER'],
    password = os.environ['MYSQL_PASSWORD'],
    database = os.environ['MYSQL_DATABASE'],
    autocommit = True
    )

    mycursor = ascspmdb.cursor()

    showtables = ("SHOW TABLES LIKE 'AbrictoSecurityAlerts%'")
    mycursor.execute(showtables)

    tables = []

    for (table,) in mycursor:
        tables.append(table)

    # Make sure we have a previous scan result to compare new results to.
    if len(tables) > 1:
        print("[+] ASCSRA has run before, now comparing latest results...")
        latesttable = tables[-1]
        previoustable = tables[-2]

        compareresults = ("""SELECT * FROM `{0}` A WHERE NOT EXISTS (SELECT 1 FROM `{1}` B WHERE A.ID = B.ID)""")

        mycursor.execute(compareresults.format(latesttable, previoustable))
        difference = mycursor.fetchall()

        if difference:
            # Read in the IgnoreAlerts.csv file as a list of tuples, and convert the tuples to strings.
            ignorenotuples = []
            with open('config/IgnoreAlerts.csv', 'r') as read_obj:
              csv_reader = reader(read_obj)
              ignoretuples = list(map(tuple, csv_reader))
              ignoretuple = 0
              for row in ignoretuples:
                ignorenotuples += [','.join([str(i) for i in row])]
                ignoretuple += 1

            # Convert the difference list of tuples to a list of strings.
            notuples = []
            atuple = 0
            for row in difference:
                notuples += [','.join([str(i) for i in row])]
                atuple += 1

            # Remove any findings that have the string "Waiting for credential report" as they are false positives
            notuples = [ x for x in notuples if "Waiting for credential report" not in x ]

            # Find alerts that the user has explicitely specified should be ignored.
            ignorethesealerts = [y for y in notuples if y.startswith(tuple(ignorenotuples))]
            if ignorethesealerts:
                print("[+] The following alerts are going to be ignored: \n",ignorethesealerts)
                # Remove alerts that should be ignored from what's been found in last scan.
                for alert in ignorethesealerts:
                  if (alert in notuples):
                    notuples.remove(alert)

            # If there's a difference between the last 2 scans, that we're not explicitely ignoring, store the delta as a new table.
            if notuples:
                difference = []
                for i in notuples:
                    difference.append(tuple(i.split(',')))
                storealerts(difference, epoch)
            else:
                print("[+] There were new alerts, but they've been explicitely ignored.")
        else:
            print("[+] There hasn't been any new alerts identified during this interrogation.")

        # Delete 'previoustable' since it's no longer needed.
        delete = ("DROP TABLE `{0}`")
        mycursor.execute(delete.format(previoustable))
        print("[+] We've just deleted the old table: " + previoustable)

    else:
        print("[-] This is the first time ASCSRA is running, no previous results to compare against yet.")
    ascspmdb.close()
    return;

def storealerts(difference, epoch):
    # Setup database connection, create new table from template, insert results, close connection.
    ascspmdb = mysql.connector.connect(
    host = os.environ['MYSQL_HOSTNAME'],
    user = os.environ['MYSQL_USER'],
    password = os.environ['MYSQL_PASSWORD'],
    database = os.environ['MYSQL_DATABASE'],
    autocommit = True
    )

    mycursor = ascspmdb.cursor()
    newtable = "CREATE TABLE `CapturedAlerts-{0}` LIKE scanResultsTemplate"
    mycursor.execute(newtable.format(epoch))

    print("[+] New alerts have been identified, now storing them in CapturedAlerts-" + epoch)
    for row in difference:
        category, title, resource, region, statusWord, message, id = row
        store = "INSERT INTO `CapturedAlerts-{0}` VALUES ('{1}','{2}','{3}','{4}','{5}','{6}','{7}')"
        mycursor.execute(store.format(epoch, category, title, resource, region, statusWord, message, id))

    ascspmdb.close()
    # Now that the results are stored, lets also email them.
    emailalerts(difference, epoch)
    return;

def emailalerts(difference, epoch):

    client = os.environ['CLIENT']
    fromemail = os.environ['FROM_EMAIL']
    toemail = os.environ['TO_EMAIL']
    primaryregion = os.environ['PRIMARY_REGION']
    print("[+] Now emailing alerts to: " + toemail)
    for row in difference:
        category, title, resource, region, statusWord, message, id = row

        # We use a generic template for formatting the HTML email.
        copyfile('templates/reports/ASCSRA-Email-Alert-Template.json', '/tmp/ASCSRA-Email-Alert.json')

        replaceclient = 'sed -i "s/%%CLIENT%%/' + client + '/g" "/tmp/ASCSRA-Email-Alert.json"'
        subprocess.call(replaceclient, shell=True)

        replacemessage = 'sed -i "s/%%TITLE%%/' + title + '/g" "/tmp/ASCSRA-Email-Alert.json"'
        subprocess.call(replacemessage, shell=True)

        date = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(int(epoch)))
        replacedate = 'sed -i "s/%%DATE%%/' + date + '/g" "/tmp/ASCSRA-Email-Alert.json"'
        subprocess.call(replacedate, shell=True)

        rawbody = 'Service: ' + category + '</br>' + 'Alert: ' + message + '</br>' + 'Resource: ' + resource + '</br>' + 'Region: ' + region + '</br>' + 'Recommendation: <a href=https://cloudsploit.com/remediations/aws/' + category.lower() + '/' + title.replace(" ", "-").lower() + '>Click here</a>'
        body = rawbody.replace("/", "\/")
        replacebody = 'sed -i "s/%%BODY%%/' + body + '/g" "/tmp/ASCSRA-Email-Alert.json"'
        subprocess.call(replacebody, shell=True)

        sendemail = 'aws ses send-email --from ' + fromemail + ' --destination "ToAddresses=' + toemail + '"  --message file:///tmp/ASCSRA-Email-Alert.json --region ' + primaryregion
        subprocess.call(sendemail, shell=True)
        os.remove("/tmp/ASCSRA-Email-Alert.json")

    return;

# Call main function.
if __name__ == '__main__':
    main()
