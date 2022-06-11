#!/bin/bash

Find_Interface () {

  #First we check which interface is connected. The system checks that  wi-fi is connected. If not, it searches for ethernet
  echo The system is checking if you are connected to your router through wi-fi or Ethernet

  if [[ $(nmcli device status | grep " wifi " | sed -n -e 's/^.*wifi  //p' | awk '{print $1}') == 'connected' ]]
  then
      cur_interface=$(nmcli device status | grep " wifi " | awk '{print $1}')
      echo You are using a wifi connection
  elif [[ $(nmcli device status | grep "ethernet" | sed -n -e 's/^.*ethernet  //p' | awk '{print $1}') == 'connected' ]]
  then
      cur_interface=$(nmcli device status | grep "ethernet" | awk '{print $1}')
      echo You are using an Ethernet connection
  else
      echo No wifi or ethernet connection to LAN was found
  fi

}

Set_Port () {

    #Now we decide which port will be opened. There are 3 options: 50577, 50578 and 50579

    cur_port=0

    #We first try to assign port 50577
    busy_port=$(netstat | grep tcp | sed 's/^.*'$1'.//' | awk '{print $1}' | grep "50577")

    #If that port is being used by another service we try with port 50578
    if [[ busy_port -eq 50577 ]]
    then
        echo Port busy, trying another port
        busy_port=$(netstat | grep tcp | sed 's/^.*'$1'.//' | awk '{print $1}' | grep "50578")
        #If that port is being used by another service we try with port 50579
        if [[ busy_port -eq 50578 ]]
        then
            echo Port busy, trying another port
            busy_port=$(netstat | grep tcp | sed 's/^.*'$1'.//' | awk '{print $1}' | grep "50579")
            #If that port ia also being used, then the system cannot receive files
            if [[ busy_port -eq 50579 ]]
            then
                echo no ports available. Try again later!
            else
                cur_port=50579
            fi
        else
            cur_port=50578
        fi
    else
        cur_port=50577
    fi
}

Connect_Port () {

    iprx1=$(nmap $1/$2 -p 50577 -Pn| grep -B4 "50577/tcp open" | grep "Nmap scan report for " | sed -n -e 's/^.*Nmap scan report for //p' | awk '{print $1}')

    IFS=. read ip1r1 ip1r2 ip1r3 ip1r4 <<< "$iprx1"
    IFS=. read ipn1 ipn2 ipn3 ipn4 <<< "$1"

    if [[ "$ip1r1" != "$ipn1" ]]
    then
        iprx2=$(nmap $1/$2 -p 50578 -Pn| grep -B4 "50578/tcp open" | grep "Nmap scan report for " | sed -n -e 's/^.*Nmap scan report for //p' | awk '{print $1}')
        IFS=. read ip2r1 ip2r2 ip2r3 ip2r4 <<< "$iprx2"
        if [[ "$ip2r1" != "$ipn1" ]]
        then
            iprx3=$(nmap $1/$2 -p 50579 -Pn| grep -B4 "50579/tcp open" | grep "Nmap scan report for " | sed -n -e 's/^.*Nmap scan report for //p' | awk '{print $1}')
            IFS=. read ip3r1 ip3r2 ip3r3 ip3r4 <<< "$iprx3"
            if [[ "$ip3r1" != "$ipn1" ]]
            then
                echo No available port found in the receiver. Please try again later
            else
                #echo Port 50579 found
                $(nc $iprx3 50579 < $3)
                echo connecting to port 50579
            fi
        else
            #echo Port 50578 found
            $(nc $iprx2 50578 < $3)
            echo connecting to port 50578
        fi
    else
        $(nc "$p1" 50577 < $3)
        echo connecting to port 50577
    fi
}


Find_Network_Address () {

    #It receives the ip and the mask
    IFS=. read ip1 ip2 ip3 ip4 <<< "$1"
    IFS=. read m1 m2 m3 m4 <<< "$2"

    ipm1=$(($ip1 & $m1))
    ipm2=$(($ip2 & $m2))
    ipm3=$(($ip3 & $m3))
    ipm4=$(($ip4 & $m4))
    ipm4=$(($ipm4+1))

    echo $ipm1.$ipm2.$ipm3.$ipm4

}

Find_Interface_Mask () {
#This function returns the number of bits on for the mask, needed for nmap
    IFS=. read m1 m2 m3 m4 <<< "$1"
    bits_mask=$((0))

    m1b=$(Convert_bits $m1)
    m2b=$(Convert_bits $m2)
    m3b=$(Convert_bits $m3)
    m4b=$(Convert_bits $m4)

    for (( i=0; i<${#m1b}; i++ )); do
        if [[ ${m1b:$i:1} == "1" ]]
        then
            bits_mask=$((bits_mask+1))
        fi
    done

    for (( i=0; i<${#m2b}; i++ )); do
        if [[ ${m2b:$i:1} == "1" ]]
        then
            bits_mask=$((bits_mask+1))
        fi
    done

    for (( i=0; i<${#m3b}; i++ )); do
        if [[ ${m3b:$i:1} == "1" ]]
        then
            bits_mask=$((bits_mask+1))
        fi
    done

    for (( i=0; i<${#m4b}; i++ )); do
        if [[ ${m4b:$i:1} == "1" ]]
        then
            bits_mask=$((bits_mask+1))
        fi
    done

    echo $bits_mask
}

Convert_bits () {
    echo "obase=2;$1" | bc
}

function instructions () {
    printf "This is Txcat. This script that allows to send/receive files without configuring ports or ip addresses using ncat."
    printf " Command Summary:\n"
    printf " -s <path/filename>               Send <filename>. If the file is not in the current folder add the whole path e.g. (/home/folder1/filename.txt). \n"
    printf " -r <filename>                    Receive file. Filename is mandatory. File will be saved in the current directory. \n"
    printf " -h                               Help.\n"
    exit 0
}


while getopts ":sr:h" opt; do
    case "${opt}" in
      h)
         instructions
        ;;
      s) file_name=${OPTARG}
         Find_Interface
         IPaddress=$(ifconfig $cur_interface | grep -w "inet" | sed -n -e 's/^.*inet //p' | awk '{print $1}')
         mask=$(ifconfig $cur_interface | grep -w "netmask" | sed -n -e 's/^.*netmask //p' | awk '{print $1}')
         Nadd=$(Find_Network_Address $IPaddress $mask)
         Bmask=$(Find_Interface_Mask $mask)
         portRX=$(Connect_Port $Nadd $Bmask $file_name)
         echo $portRX
         echo file sending process ended.
          #echo $folder
       ;;
      r) file_name=${OPTARG}
         Find_Interface
         IPaddress=$(ifconfig $cur_interface | grep -w "inet" | sed -n -e 's/^.*inet //p' | awk '{print $1}')
         mask=$(ifconfig $cur_interface | grep -w "netmask" | sed -n -e 's/^.*netmask //p' | awk '{print $1}')
         Set_Port $IPaddress
         #The port is opened twice: First for ip+port checking and then to receive the file
         echo $cur_port
         echo $file_name
         echo $IPaddress
         a=1
         while [[ $a -le 2 ]]
         do
            $(nc -l $cur_port > $file_name)
            a=$((a+1))
         done
         echo finished receiving file.
         #TODO: some authentication mechanism should be implemented
       ;;
      *)
         printf "Please use a valid option. Option: $1 cannot be used. Use -h for help. \n"
         instructions
       ;;
    esac
done
