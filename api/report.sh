#!/bin/bash

# Accept an interval as the only argument, Daily, Weekly, Monthly
INTERVAL=$1

# Specify the working directory and documents we'll need
REMEDIATIONSTOC="/tmp/$INTERVAL-REMEDIATIONSTOC.html"
ALERTSTOC="/tmp/$INTERVAL-ALERTSTOC.html"
NUMERICDATE=$(date +'%Y%m%d')
DATE=$(date)
CLIENT=$(grep -oP "(?<=client = ).*" ./ascsra.config)
REPORT="/tmp/ASCSRA-Scan-Report-$INTERVAL-$NUMERICDATE.html"

# See what timeframe we need to report for.
case $INTERVAL in
  "Daily")
  ALLREMEDIATIONINSTANCES=""#$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call DailyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ALLALERTINSTANCES=$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call DailyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ;;

  "Weekly")
  ALLREMEDIATIONINSTANCES=""#$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call WeeklyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ALLALERTINSTANCES=$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call WeeklyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ;;

  "Monthly")
  ALLREMEDIATIONINSTANCES=""#$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call MonthlyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ALLALERTINSTANCES=$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call MonthlyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ;;

  "Yearly")
  ALLREMEDIATIONINSTANCES=""#$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call YearlyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ALLALERTINSTANCES=$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call YearlyAlerts();" | sed 's/\t/,/g' | tail -n +2)
  ;;

  *)
  printf "[-] No interval or incorrect interval entered as argument to this script.\n"
  exit
  ;;
esac

# Check if we didn't have any alerts or remediations for this time period. If not, don't report.
# if [[ -z "$ALLALERTINSTANCES" && -z "$ALLREMEDIATIONINSTANCES" ]]; then
#  printf "[-] No alerts were generated or remediations attempted during this time period, not reporting.\n"
#  exit
# fi

# Check if we didn't have any alerts or remediations for this time period. If not, don't report.
if [[ -z "$ALLALERTINSTANCES" ]]; then
  printf "[-] No alerts were generated or remediations attempted during this time period, not reporting.\n"
  exit
fi

# Create a working document from our template
cp "./templates/reports/ASCSRA-Scan-Report-Template.html" "$REPORT"

# Check if we had any alerts, if so, report. Else, move on to remediations.
if [ -z "$ALLALERTINSTANCES" ]; then
  printf "[-] No alerts were generated during this time period.\n"
  sed -i "s/%%ALERTSTOC%%/None/g" "$REPORT"
else
# Add "Alerts by Timestamp" header
  cat <<EOT >> $REPORT
<div style="width: 100%;">
<h6 xmlns="" style="padding: 20px 0; border-top: 1px dotted #ccc; border-bottom: 1px dotted #ccc; font-size: 20px; font-weight: 100; line-height: 20px;">Alerts by Timestamp<span onclick="toggleAll();" class="expand">Expand All</span><span class="expand-spacer"> | </span><span onclick="toggleAll(true);" class="expand">Collapse All</span>
</h6>
</div>
EOT

  # Iterate through all the alerts generated
  while IFS= read -r ALERTINSTANCE;
  do
    ALERTDATE=$(echo $ALERTINSTANCE | cut -d "," -f 1)
    ID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13)
    NUMBEROFALERTS=$(echo $ALERTINSTANCE | cut -d "," -f 2)
    INSTANCEALERTS=$(mysql -h$MYSQL_HOSTNAME -D$MYSQL_DATABASE -u$MYSQL_USER -p$MYSQL_PASSWORD -e "call InstanceAlerts('$ALERTDATE');" | sed 's/\t/,/g' | tail -n +2)
    PREPENDEXCLAMATION=$(while IFS= read -r line; do echo "[!] $line" | sed 's/$/<br>/g'; done <<< $INSTANCEALERTS)
    OUTPUT=$(echo $PREPENDEXCLAMATION | sed 's/\\/\\\\/g' | sed 's/\//\\\//g' | tr -d '\n')

    # Generate a table of contents entry for each set of alerts
    cat <<EOT >> $ALERTSTOC
<li style="margin: 0 0 10px 0; color: #000000;"><a href="#%%ID%%" onclick="toggleSection('%%ID%%-container');">%%NUMBEROFALERTS%% Alerts: %%ALERTDATE%%</a></li>
EOT
    sed -i "s/%%ID%%/$ID/g" "$ALERTSTOC"
    sed -i "s/%%ALERTDATE%%/$ALERTDATE/g" "$ALERTSTOC"
    sed -i "s/%%NUMBEROFALERTS%%/$NUMBEROFALERTS/g" "$ALERTSTOC"

    # Generate an expandable alert content section detailing the output of the alert
    cat <<EOT >> $REPORT
<h2 xmlns="" class=""></h2>
<div xmlns="" id="%%ID%%" style="box-sizing: border-box; width: 100%; margin: 0 0 10px 0; padding: 5px 10px; background: #0071b9; font-weight: bold; font-size: 14px; line-height: 20px; color: #fff;" class="" onclick="toggleSection('%%ID%%-container');" onmouseover="this.style.cursor='pointer'">%%ALERTDATE%% - Number of Alerts: %%NUMBEROFALERTS%%<div id="%%ID%%-toggletext" style="float: right; text-align: center; width: 8px;">
</div>
</div>
<div xmlns="" id="%%ID%%-container" style="margin: 0 0 45px 0;" class="section-wrapper">
<div class="details-header">Alerting Output<div class="clear"></div>
</div>
<div class="clear"></div>
<div style="box-sizing: border-box; width: 100%; background: #eee; font-family: monospace; padding: 20px; margin: 5px 0 20px 0;">%%OUTPUT%%<div class="clear"></div>
</div>
<div class="clear"></div>
<div class="clear"></div>
</div>
<div xmlns="" class="clear"></div>
EOT

    sed -i "s/%%ID%%/$ID/g" "$REPORT"
    sed -i "s/%%ALERTDATE%%/$ALERTDATE/g" "$REPORT"
    sed -i "s/%%NUMBEROFALERTS%%/$NUMBEROFALERTS/g" "$REPORT"
    sed -i "s/%%OUTPUT%%/$OUTPUT/g" "$REPORT"
  done <<< $ALLALERTINSTANCES

  # Incorporate the alert table of contents into the report
  ALERTSTOCCONTENTS=$(cat "$ALERTSTOC" | sed 's/\./\\\./g' | sed 's/\\/\\\\/g' | sed 's/\//\\\//g' | tr -d '\n')
  sed -i "s/%%ALERTSTOC%%/$ALERTSTOCCONTENTS/g" "$REPORT"

  rm $ALERTSTOC
fi

# Check if we had any remediations, if so, report. Else, move on.
if [ -z "$ALLREMEDIATIONINSTANCES" ]; then
  printf "[-] No remediations were attempted during this time period.\n"
  sed -i "s/%%REMEDIATIONSTOC%%/None/g" "$REPORT"
fi
# Remainder of report, nothing dynamic in here.
sed -i "s/%%INTERVAL%%/$INTERVAL/g" "$REPORT"
sed -i "s/%%DATE%%/$DATE/g" "$REPORT"
cat <<EOT >> $REPORT
<div class="clear"></div></div><div class="clear"></div></div><div style="width: 1024px; box-sizing: border-box; text-align: center; font-size: 12px; color: #999; padding: 10px 0 20px 0; margin: 0 auto;">
  © 2020 Abricto Security. All rights reserved.
</div>
</body>
</html>
EOT

# Send an email with the reports attached.
cp ./templates/reports/ASCSRA-Email-Report-Template.json /tmp/ASCSRA-Email-Report-$INTERVAL.json
cp ./templates/reports/ASCSRA-Email-Report-Template.html /tmp/ASCSRA-Email-Report-$INTERVAL.html

sed -i "s/%%INTERVAL%%/$INTERVAL/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.html"
sed -i "s/%%DATE%%/$DATE/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.html"
BODYBASE64=$(cat /tmp/ASCSRA-Email-Report-$INTERVAL.html | base64 -w 0 | sed 's/\//\\\//g')
REPORTBASE64=$(zip -q -j -D "/tmp/ASCSRA-$CLIENT-Report-$NUMERICDATE.zip" $REPORT && cat "/tmp/ASCSRA-$CLIENT-Report-$NUMERICDATE.zip" | base64 -w 0 | sed 's/\//\\\//g')

sed -i "s/%%CLIENT%%/$CLIENT/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.json"
sed -i "s/%%NUMERICDATE%%/$NUMERICDATE/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.json"
sed -i "s/%%INTERVAL%%/$INTERVAL/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.json"
sed -i "s/%%BODYBASE64%%/$BODYBASE64/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.json"
sed -i "s/%%REPORTBASE64%%/$REPORTBASE64/g" "/tmp/ASCSRA-Email-Report-$INTERVAL.json"

aws ses send-raw-email --raw-message file:///tmp/ASCSRA-Email-Report-$INTERVAL.json &> ./$FOLDER/out.log
# rm "/tmp/ASCSRA-Email-Report-$INTERVAL.json"
# rm "/tmp/ASCSRA-Email-Report-$INTERVAL.html"
# rm "/tmp/ASCSRA-$CLIENT-Reports-$NUMERICDATE.zip"
mv $REPORT "./reports/ASCSRA-Scan-Report-$INTERVAL-$NUMERICDATE.html"
