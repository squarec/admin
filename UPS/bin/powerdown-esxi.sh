#!/bin/ash
# title: powerdown-esxi4.sh
# version: 0.5
# date: october 09, 2011
# author: herwarth heitmann <herwarth@helux.nl>
# edit by: massimo vannucci <massimo.vannucci@gmail.com>

#variables
PATH=/bin:/sbin:/usr/bin:/usr/sbin
VIMSH_WRAPPER=vim-cmd
VM_FILE=/tmp/vm_list
INTERVAL=60
MAXLOOP=3
DATE=`date "+%Y-%m-%d   %H:%M:%S"`
# To enable logging, set the following variable to 1
LOG_ENABLED=1
LOG_FILE=/vmfs/volumes/SYS/UPS/log/exsi_powerdown.log
# Remember that >> after echo, redirect and append to file

# Set the log file
if [ $LOG_ENABLED -eq 1 ]; then
  echo -e "\n\n\n"`date "+%Y-%m-%d   %H:%M:%S"` "\t\tExecuting powerdown-esxi.sh" >> $LOG_FILE
  #retrieve all VmId for VM(s) registered under ESXi host
  ${VIMSH_WRAPPER} vmsvc/getallvms >> $LOG_FILE
fi

#check if parameter given
case "$1" in
    "") LASTACTION=shutdown
        ;;
reboot) LASTACTION=reboot
        ;;
vmonly) LASTACTION=vmonly
        ;;
     *) echo "usage $0 <|vmonly|reboot>"
        exit 1
        ;;
esac

#retrieve all VmId for VM(s) registered under ESXi host
${VIMSH_WRAPPER} vmsvc/getallvms | awk '{print $1}' | grep -v 'Annotation' | grep -v 'Vmid' > $VM_FILE

#first time initialisation
ERROR=0
FIRSTRUN=1
LOOP=0

#we want to run the loop at least 1 time! and loop until no more errors occur
while [ $ERROR -ne 0 -o $FIRSTRUN -eq 1 ]; do
  LOOP=$(($LOOP+1))
  if [ $FIRSTRUN -eq 0 ]; then
    if [ $LOG_ENABLED -eq 1 ]; then
      echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tGive virtual machines time to shutdown..." >> $LOG_FILE
    else
      echo "Give virtual machines time to shutdown..."
    fi
    sleep $INTERVAL
  fi
  #exit loop if $LOOP gets bigger than $MAXLOOP
  if [ $LOOP -gt $MAXLOOP ]; then
    echo "Maximum loops reached!"
    break
  fi

  FIRSTRUN=0
  ERROR=0
  for VM_LINE in $(cat ${VM_FILE}); do
    STATE=$(${VIMSH_WRAPPER} vmsvc/power.getstate ${VM_LINE} | grep -v 'runtime')
    if [ "$STATE" = "Powered off" -o "$STATE" = "Suspended" ]; then
      if [ $LOG_ENABLED -eq 1 ]; then
        echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tVM with ID: ${VM_LINE} is: $STATE, skipping..." >> $LOG_FILE
      else
        echo "VM with ID: ${VM_LINE} is: $STATE, skipping..."
      fi
    else
      #try to do proper shutdown if VMware Tools are installed
      if [ $LOG_ENABLED -eq 1 ]; then
        echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tVM with ID: ${VM_LINE:} is: $STATE, trying guest shutdown..." >> $LOG_FILE
      else
        echo "VM with ID: ${VM_LINE} is: $STATE, trying guest shutdown..."
      fi
      ${VIMSH_WRAPPER} vmsvc/power.shutdown "${VM_LINE}" > /dev/null 2>&1
      #if it fails to shutdown, we know there are no VMware Tools installed
      if [ $? -eq 1 ]; then
        #hard power off
        if [ $LOG_ENABLED -eq 1 ]; then
          echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tGuest shutdown not working, hard powering off" >> $LOG_FILE
        else
          echo -e "\tGuest shutdown not working, hard powering off"
        fi
        ${VIMSH_WRAPPER} vmsvc/power.off "${VM_LINE}" > /dev/null 2>&1
      else
        if [ $LOG_ENABLED -eq 1 ]; then
          echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tSuccessfully initiated shutdown of ${VM_LINE}" >> $LOG_FILE
        else
          echo -e "\t\tSuccessfully initiated shutdown of ${VM_LINE}"
        fi
      fi
      ERROR=$(($ERROR+1))
    fi
  done
done

# clean up temporary file
rm -f $VM_FILE

#execute last action
case "$LASTACTION" in
shutdown) #shutdown ESXi host
          if [ $LOG_ENABLED -eq 1 ]; then
            echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tShutting down ESXi host..." >> $LOG_FILE
          fi
          /sbin/poweroff
          ;;
  reboot) #reboot ESXi host
          if [ $LOG_ENABLED -eq 1 ]; then
            echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tRebooting ESXi host..." >> $LOG_FILE
          fi
          /sbin/reboot
          ;;
  vmonly) #do nothing! only VMs needed to be shutdown
          if [ $LOG_ENABLED -eq 1 ]; then
            echo -e `date "+%Y-%m-%d   %H:%M:%S"` "\t\tDo nothing with ESXi host..." >> $LOG_FILE
          fi
          ;;
esac
exit 0
