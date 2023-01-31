DAY1="test192" ## DAY1 is the variable to which we are saving the VM name.
DAY2="test250 test199" ## For multiple VMs you can separate the VMs using space. 

excludes=""
shareFolder="/backup-vms/" ## NAS directory, where the backups will be sent and saved.
mountPoint="/mnt/backup/" ## XenServer directory, where the NAS directory is mounted.
backupDir="/mnt/backup/vms/" ## XenServer directory, where the backups will be kept before sending to NAS.
nfsServer="192.168.1.100"  ## NAS Server IP Address. 
year=`date +%Y` 
month=`date +%b` 

## Finding the UUID of the VMs and list he exported VMs -
print_usage()
{
   echo -e "Usage: \n\t$0 [help] [ $options ]"
   exit
}

print_usage_help()
{
   echo -e "[ ${1,,} ] will export:"
   for i in ${!1}
   do
      uuid=$(get_vm_uuid $i)
      echo -e -n "\t- $i"
      if [ -z "$uuid" ]
      then
          echo -e " (does not exists)"
      else
          echo -e ""
      fi
   done
   exit
}

## Check the mount point, if not mounted properly it try and mount the NAS drive and not sucessfull it will not send the files. 
check_mount()
{
   echo -e -n "Checking if mount exists ... "
   mnt_out=`mount -l -t nfs | grep $mountPoint | awk '{print($3)}'`
   if [ -n "$mnt_out" ]
   then
      echo -e "mounted"
   else
      echo -e "[$mountPoint] not mounted"
      echo -e -n "Attempting to mount $mountPoint..."
      nfs_mnt_out=`mount -t nfs $nfsServer:$shareFolder $mountPoint`
      if [ $? -gt 0 ]
      then
         echo -e "failed to mount [$mountPoint]\n"
         echo -e "Exiting"
         exit
      else
         echo -e "[$mountPoint] mounted\n"
      fi
   fi
}

unMount()
{
   echo -e -n "Checking if mount exists..."
   mnt_out=`mount -l -t nfs | grep $mountPoint | awk '{print($3)}'`
   if [ -n "$mnt_out" ] && [ -n "$mountPoint" ]
   then
      echo -e "[$mountPoint] still mounted"
      echo -e -n "Attempting to unmount [$mountPoint]..."
      nfs_mnt_out=`umount /mnt/backup/`
      if [ $? -gt 0 ]
      then
         echo -e "failed to unmount [$mountPoint]"
      else
         echo -e "[$mountPoint] unmounted"
      fi
   else
      echo -e "unknown error unmounting [$mountPoint]"
   fi
}

## Get the size of the VM
get_vm_size()
{
   local vdisk_size=`/usr/bin/xe vm-disk-list vm=$1| grep virtual-size | awk '{print(\$4)}'`

   for i in $vdisk_size
   do
      local vm_disk_size=$(($vm_disk_size + $i))
   done

   echo -e $vm_disk_size
}

## Get the available space of the VM 
get_disk_available_space()
{
   local free_disk_space=`df --block-size=1 /var/mnt/backup| tail -1 | awk '{print(\$4)}'`
   echo -e $free_disk_space
}

check_vm_powerstate()
{
   cvp_out=`/usr/bin/xe vm-list params=power-state name-label=$1`
   cvp_powerstate=`echo $cvp_out | awk '{print(\$NF)}'`
   echo $cvp_powerstate
}

shut_down_vm()
{
   sdv_powerstate=$(check_vm_powerstate $1)

   case $sdv_powerstate in
      "halted")
         echo -e "halted"
         ;;
      "running")
         echo `/usr/bin/xe vm-shutdown name-label=$1`
         ;;
      *)
         echo -e "$1 in state not ready for exporting"
         ;;
   esac
}

start_vm()
{
   sv_powerstate=$(check_vm_powerstate $1)

   case $sv_powerstate in
      "running")
         echo -e "running"
         ;;
      "halted")
         sv_out=`/usr/bin/xe vm-start name-label=$1`
         sleep 10
         sv_ps=$(check_vm_powerstate $1)
         echo $sv_ps
         ;;
      *)
         echo -e "$1 in state not ready for starting"
         ;;
   esac
}

get_vm_uuid()
{
   uuid=`/usr/bin/xe vm-list name-label=$1|grep uuid | awk '{print(\$5)}'`
   echo "$uuid"
}

check_excluded()
{
   for ex in $excludes
   do
      if [ "$1" = "$ex" ]
      then
        echo "Found: \$1:$1 exclude:$ex"
      fi
   done
}

export_vm()
{
   if [ ! -d $backupDir/$year/$month/$1 ]
   then
      mkdir -p $backupDir/$year/$month/$1
   fi

   if [ $? -gt 0 ]
   then
      echo -e "$backupDir/$year/$month/$1 no such file or directory"
   else
      ex_vm=`/usr/bin/xe vm-export vm=$1 filename=$backupDir/$year/$month/$1/$2.xva`
      echo $?
   fi
}

check_exists()
{
   local list=""
   local vms=${!1}

   for x in $vms
   do
      uuid=$(get_vm_uuid $x)

      if [ -z $uuid ]
      then
         list="$list"
      else
         list="$list $x"
      fi
   done

   echo -e "$list"
}

if [ -z "$*" ]
then
  print_usage
fi

case $1 in
   "help")
      if [ -z $2 ]
      then
         print_usage
      else
         print_usage_help ${2^^}
      fi
      ;;
   *)
      vm_group=${1^^}

      if [ -z "${!vm_group}" ]
      then
         print_usage
         exit
      fi

      echo -e "Will attempt to export ..... ${!vm_group}"
      check_mount
      fds=$(get_disk_available_space)


      for v in ${!vm_group}
      do
         uuid=$(get_vm_uuid $v)
         if [ -z "$uuid" ]
         then
            #echo -e " (does not exists)"
            echo -e -n ""
         else
            #echo -e ""
            vm_size=$(get_vm_size $v)
            space_required=$(($space_required + $vm_size))
         fi
      done

      echo -e "Disk Space Available ....... $((fds / 1024000000))GB"
      echo -e "Disk Space Needed .......... $((space_required / 1024000000))GB"

      if [ $fds -lt $space_required ]
      then
         echo -e "Not enough space available to export"
         echo -e "exiting"
         exit
      fi

      echo -e -n "Attempting to shutdown ....."

      for vm in ${!vm_group}
      do
         echo -e -n " $vm="
         state=$(check_vm_powerstate $vm)

         case "$state" in
         "running")
            state=$(shut_down_vm $vm)
            state=$(check_vm_powerstate $vm)
            ;;
         "halted")
            state=$(check_vm_powerstate $vm)
            ;;
         *)
            excludes="$excludes $vm"
            ;;
         esac

         echo -en "$state "
      done

      echo -e ""

      if [ -n "$excludes" ]
      then
         echo -e "Excluded ...................$excludes"
      fi

      ex_rval=1
      echo -en "Exporting .................. "

      for vm in ${!vm_group}
      do
         echo -en "$vm="
         rval=$(check_excluded $vm)

         if [ -z "$rval" ]
         then
            uuid=$(get_vm_uuid $vm)
            ex_rval=$(export_vm $vm $uuid)

            if [ "$ex_rval" = "0" ]
            then
               echo -en "exported "
            else
               echo -en "failed "
            fi
         else
               echo -en "excluded "
         fi
      done
      echo ""

      echo -en "Attempting to start ........ "

      for vm in ${!vm_group}
      do
         echo -en "$vm="
         rval=$(check_excluded $vm)

         if [ -n "$rval" ]
         then
            echo -en "excluded "
         else
            state=$(start_vm $vm)
            state=$(check_vm_powerstate $vm)
            if [ "$state" != "running" ]
            then
               state=$(start_vm $name)
               state=$(check_vm_powerstate $name)
               echo -en "$state "
            else
               echo -en "$state "
            fi
         fi
      done

      echo ""
      ;;
esac

exit
