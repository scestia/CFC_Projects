#!/bin/bash

# 1. Retrieve Public IP Address
echo "1. Your Public IP Address is:"
curl -s --connect-timeout 5 <https://api.ipify.org> || echo "Error: Unable to retrieve public IP" #A web service that returns our public IP address
echo -e "\n"

# 2. Retrieve Internal IP Address of the machine
echo "2. Your Internal IP Address is:"
ifconfig | grep inet | awk '{print $2}' | head -1 
echo -e "\n"

# 3. Retrieve and censor MAC Address
echo "3. Your MAC Address (Censored) is:"
mac=$(ifconfig | awk '/ether/ {print $2}')
censored_mac=$(echo $mac | sed 's/^\(..:..:..:\)..:..:..$/\1XX:XX:XX/') #using sed to parse and subsitute the last 3 segment with XX
echo $censored_mac
echo -e "\n"

# 4. Display the Top 5 Processes by CPU usage
echo "4. Your Top 5 Processes by CPU usage:"
ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6 #List all processses, PID and CPU usage and sort by CPU usage. Show only the top 5 processes including the header.
echo -e "\n"

# 5. Display Memory Usage (Free and Used)
echo "5. Memory Usage (Free and Used):"
free -h | awk '/^Mem:/ {print "Used: "$3, "\nFree: "$4}' | sed 's/Gi/GB/g; s/Mi/MB/g' #using sed here simply because i don't like to read it as Gi and prefer it to be GB or MB
echo -e "\n"

# 6. Display System's Active Services and Status
echo "6. Your Active Services and Status:"
systemctl list-units --type=service --state=running --no-pager
echo -e "\n"

# 7. Display the Top 10 Largest files from /home directory
echo "7. Your Top 10 Largest Files from /home Directory:"
echo -e "Size\tLocation" #Adding a header for content description
find /home -readable -type f -exec du -h {} + 2>/dev/null | sort -rh | head -n 10 #sort with -rh to get the bigger size on top and display top 10
