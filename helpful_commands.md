

```bash
uname -a

cat /sys/firmware/devicetree/base/model 


# Hardware info 
cat /proc/cpuinfo
hostnamectl
free -h
sudo raspi-config 
lsb_release -a
```

```bash
sudo nano /boot/firmware/cmdline.txt
```
```bash
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```
```bash
cat /sys/fs/cgroup/cgroup.controllers
cat /proc/cmdline
cat /proc/cgroups | grep memory
```

```bash
#If you know your network name and password, you can connect in a single line.

#List networks to confirm yours is visible:
nmcli device wifi list
#Connect using this command (replace with your details):
sudo nmcli device wifi connect "Your_SSID" password Your_Password"
#Verify the connection:
nmcli connection show --active
```

```bash
sudo vim /etc/hosts
```