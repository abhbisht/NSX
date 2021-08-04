# NSX-T VM2IP Script 

This script added Dynamic Members of NSX-T Security Group as static IP members, which can be used for NSX-T to T Migrations

This script have two modes: 
1. Migrate 
   - Backup NS Group Configuration
   - Get IP addresses that belong to NS Groups . (This is applicable for Groups containing either VM, VIF, Segment, Segment Port or IP Address member type) 
   - Create a new temporary group with nsxt-migration- prefix followed by group name add learnt IP addresses as static members
   - Add nsxt-migration group as nested member of existing group
                               
2. Cleanup
   - Apply NS Group Backup configuration - This removes nsxt-migration groups from child membership of existing groups
   - Delete nsxt-migration groups

To execute script, copy it to any linux system which can access NSX-T Manager or directly on NSX-T Manager root shell. 

  #sh nsxt-vm2ip_script.sh 
    
It will prompt for NSX Manager IP and password and execution mode.
