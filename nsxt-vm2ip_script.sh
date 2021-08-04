# !/bin/bash
#Author: Abhishek Bisht


echo "
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

Script to Add IP Addresses to groups for NSX-T to NSX-T Migration
	
This script will get read IP Addresses associated with NS groups
and create a temporary NS group with nsxt-migration-<ns_group_name> prefix
and add IP addresses as static member of migration group and add migration 
group as child of NS group. 

Note: 1. Ensure to have NSX backup prior to run the script
2. No Changes in Group Membership permitted during migration
3. NS Groups must not have space char in naming 

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
"

echo "Enter NSX Manager IP"
read nsxip
echo "Enter NSX Manager admin Password"
read nsxpass
echo "

###########################################################################
###########################################################################
	
Type: migrate - To configure tmp NS groups and add it as child of NS Group 
	cleanup - To perform Cleanup - Remove tmp NS Groups after migration

###########################################################################
###########################################################################


"
read option
case ${option} in
"migrate")
echo  "######################################################################
Creating Migration temporary Directories
/tmp/nsxt-migration - ALL temporary files and sub-directory
/tmp/nsxt-groups-backup - Backup of NS Groups
~/nsxt-groups-backup - Second Backup Directory in user home directory
######################################################################
 " 
mkdir -p /tmp/nsxt-migration
mkdir -p /tmp/nsxt-migration/groups
mkdir -p /tmp/nsxt-migration/new_groups
mkdir -p /tmp/nsxt-groups-backup
mkdir -p ~/nsxt-groups-backup



### Section 1 - GET IP Addresses of each Groups ###

### Get all Groups ###

curl -X GET "https://$nsxip/policy/api/v1/infra/domains/default/groups"   -H "Accept: application/json" -k -u admin:"$nsxpass" > /tmp/nsxt-migration/groups_details.txt

## Grep only Path of all Groups ##
grep "\"resource_type\" : \"Group\"" -A 3 /tmp/nsxt-migration/groups_details.txt  | grep "\"path\"" | tr -d " " | cut -d: -f2 | tr -d "\"" | tr -d "," > /tmp/nsxt-migration/group_path.txt

echo "###### Backup Group configuration ####"
for i in `cat /tmp/nsxt-migration/group_path.txt`; do curl -X GET "https://$nsxip/policy/api/v1$i" -H "Accept: application/json" -k -u admin:"$nsxpass" > ~/nsxt-groups-backup/`echo $i | cut -d/ -f6`; done 
for i in `cat /tmp/nsxt-migration/group_path.txt`; do curl -X GET "https://$nsxip/policy/api/v1$i" -H "Accept: application/json" -k -u admin:"$nsxpass" > /tmp/nsxt-groups-backup/`echo $i | cut -d/ -f6`; done

sleep 5
cp -rf /tmp/nsxt-groups-backup /tmp/nsxt-groups-backup-`date +%Y_%m_%d_%H_%M`
cp -rf /tmp/nsxt-groups-backup ~/nsxt-groups-backup-`date +%Y_%m_%d_%H_%M`

echo "

### Fetching individual Group Associated IP Addresses Details  ##


"

## API Call to Fetching Group Details 
for i in `cat /tmp/nsxt-migration/group_path.txt`; do curl -X GET "https://$nsxip/policy/api/v1$i/members/ip-addresses" -H "Accept: application/json" -k -u admin:"$nsxpass" > /tmp/nsxt-migration/groups/`echo $i | cut -d/ -f6`; done


### Section 2 -  Create New Groups ###

echo "

### Creating New Temp Groups ###

"
## Getting only IP Addresses 
#grep "\"results\"" /tmp/nsxt-migration/groups/* | tr -d " " |tr -d "," |  cut -d: -f2

### Removing Groups details with no IP Address ##
#for i in `ls /tmp/nsxt-migration/groups`; do if [[ `grep "\"result_count\"" /tmp/nsxt-migration/groups/$i | tr -d " " |tr -d "," |  cut -d: -f2` -eq 0 ]]; then rm -f /tmp/nsxt-migration/groups/$i ; fi; done
for i in `ls /tmp/nsxt-migration/groups`; do if [ `grep "\"result_count\"" /tmp/nsxt-migration/groups/$i | tr -d " " |tr -d "," |  cut -d: -f2` -eq 0 ]; then rm -v /tmp/nsxt-migration/groups/$i; fi; done
#sh /tmp/nsxt-migration/empty_group_file_remove.sh


grep "BAD_REQUEST"  /tmp/nsxt-migration/groups/* | cut -d: -f1  > /tmp/nsxt-migration/bad-groups
for i in `cat /tmp/nsxt-migration/bad-groups`; do rm -v $i ; done 

sleep 60

#rm /tmp/nsxt-migration/empty_group_file_remove.sh 
## API Call to create new groups with IP Address ##  

for i in `ls /tmp/nsxt-migration/groups`;  do ip_addr=`grep "\"results\"" /tmp/nsxt-migration/groups/$i | tr -d " " | cut -d: -f2`; echo "{\"expression\": [
    {
      \"ip_addresses\": $ip_addr
  \"resource_type\": \"IPAddressExpression\"
  }
  ]
  }" > /tmp/nsxt-migration/new_groups/nsxt-migration-$i; done
  
echo "

## Creating new temp NS groups with nsxt-migration-prefix + same_name ##

"
for i in `ls /tmp/nsxt-migration/new_groups`; do curl -X PUT "https://$nsxip/policy/api/v1/infra/domains/default/groups/$i" -H "Content-Type: application/json" -k -u admin:"$nsxpass" -d "@/tmp/nsxt-migration/new_groups/$i";echo "

######  Created Temp NS Group $i  ###########"; sleep 2;  done


### Section 3 - Adding new group nsxt-migration child of parent group ##

echo "

## Adding new temp group as child of NSX Groups ##

" 

for i in `ls /tmp/nsxt-migration/groups`; do group_update=`curl -X GET  "https://$nsxip/policy/api/v1/infra/domains/default/groups/$i" -H "Content-Type: application/json" -k -u admin:"$nsxpass" | sed '/\"expression\"/a \"paths\": [ \"/infra/domains/default/groups/nsxt-migration-'$i'" ], \n  \"resource_type\": \"PathExpression\" }, { \n \"conjunction_operator\": \"OR\", \n \"resource_type\": \"ConjunctionOperator\" }, { ' `;  curl -X PUT "https://$nsxip/policy/api/v1/infra/domains/default/groups/$i" -H "Content-Type: application/json" -k -u admin:"$nsxpass" -d "$group_update"; echo " 

########  Modified NS Group $i ######

" ; sleep 2; done ;;



"cleanup")
### Section 4 - Cleanup new groups 


echo "

##  Applying pre-captured group configuration backup ##

"

for i in `ls /tmp/nsxt-migration/groups` ; do curl -X PATCH "https://$nsxip/policy/api/v1/infra/domains/default/groups/$i" -H "Content-Type: application/json" -k -u admin:"$nsxpass" -d "@/tmp/nsxt-groups-backup/$i"; echo "Modified NS Group $i"; sleep 2; done


echo "

## Deleting temp NS groups ##

"
for i in `ls /tmp/nsxt-migration/new_groups`; do curl -X DELETE "https://$nsxip/policy/api/v1/infra/domains/default/groups/$i" -H "Content-Type: application/json" -k -u admin:"$nsxpass" ; echo "Deleted temp NS Group $i" ; sleep 2; done;;

esac
