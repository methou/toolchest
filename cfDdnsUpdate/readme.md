This folder contains a collection of script I wrote for implementing dynamic dns record update. 

#   Scripts

##  cfUpdateWithSnmp.sh
... is a bash script work with SNMP, it gets IP addresses from an SNMP server and pushes records to CloudFlare server

## Prerequisites

SNMP - for obvious reasons;
snmp-mibs-downloader - mibs files doesn't come with SNMP by default;
jq - json parser;

On debian/alike: `sudo aptitude install snmp snmp-mibs-downloader jq` then `sudo download-mibs`
you should be fine.

### Usage
First please 
`chmod 700 cfUpdateWithSnmp.sh`
... to limit access to yourself only, and gives executable perm to the script, so we can add it to cronjobs later.

Add edit following parameters accordingly:

```bash
cfLogin="" # your CloudFlare login email address. >> me@example.org
cfSecret="" # Your CloudFlare API key (Global), get this from account page 
cfDomain="" # Your domain name. >> example.org
cfRecordNames="" # subdomain name, or a list of sub domain name
                 # >> "abc" for abc.example.org
                 # >> (sub1 sub2 sub3) for a list of subdomains

mkHostIp="" # Hostname or IP address of your SNMP server >> "192.168.88.1"
mkSnmpCommunity="" # SNMP community name, set accordingly. >> "public"
mkSnmpIfId="" # Interface ID you read from SNMP, 
              # NOTE if you use a list in cfRecordNames:
              # Number and order must match with cfRecordNames.
```

Then please run
`mkdir ${HOME}/etc`
which is a folder holds IP address(es) information.

Run
`./cfUpdateWithSnmp.sh`

If everything works, and you want to use it with cron:
`crontab -e`
`*/5 * * * * /home/qzhou/exp/refreshIp.sh`
runs every 5 minutes

### TODO
If ETC folder or STATUS_FILE doesn't exist, they should be automatically created.
mkSnmpIfId can be retrieved from SNMP, so no need to set.



