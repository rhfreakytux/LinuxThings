### Preparation

-   Ensure the following ports are open to your Linux host on your domain controller:

| Service  | Port(s)           | Comments                                                    |
|:---------|:------------------|:------------------------------------------------------------|
| DNS      |      53 (TCP+UDP) |                                                             |
| Kerberos | 88, 464 (TCP+UDP) | Used by `kadmin` for setting &amp; updating passwords       |
| LDAP     |     389 (TCP+UDP) |                                                             |
| LDAP-GC  |        3268 (TCP) | LDAP Global Catalog - allows you to source user IDs from AD |  

**With NetworkManager:**
```
# where your primary NetworkManager connection is 'System eth0' and your AD
# server is accessible on the IP address 10.0.0.2.

[root@host ~]$ nmcli con mod 'System eth0' ipv4.dns 10.0.0.2
```

**Manually editing the /etc/resolv.conf:**
```
# Edit the resolv.conf file
[user@host ~]$ sudo vi /etc/resolv.conf
search lan
nameserver 10.0.0.2
nameserver 1.1.1.1 # replace this with your preferred public DNS (as a backup)

# Make the resolv.conf file unwritable, preventing NetworkManager from
# overwriting it.
[user@host ~]$ sudo chattr +i /etc/resolv.conf
```
* Ensure that the time on both sides (AD host and Linux system) is synchronized

**To check the time on Rocky Linux:**
```
[user@host ~]$ date
Wed 22 Sep 17:11:35 BST 2021
```

-   Install the required packages for AD connection on the Linux side:
```
[user@host ~]$ sudo dnf install realmd oddjob oddjob-mkhomedir sssd adcli krb5-workstation
```

### Discovery
Now, we should be able to successfully discover our AD server(s) from our Linux host.

```
[user@host ~]$ realm discover ad.company.local
ad.company.local
  type: kerberos
  realm-name: AD.COMPANY.LOCAL
  domain-name: ad.company.local
  configured: no
  server-software: active-directory
  client-software: sssd
  required-package: oddjob
  required-package: oddjob-mkhomedir
  required-package: sssd
  required-package: adcli
  required-package: samba-common
```
This will be discovered using the relevant SRV records stored in your Active Directory DNS service.

### Joining
Once we have successfully discovered our Active Directory installation from the Linux host, we should be able to use `realmd` to join the domain, which will orchestrate the configuration of `sssd` using `adcli` and some other such tools.

```
[user@host ~]$ sudo realm join ad.company.local
```

If this process complains about encryption with `KDC has no support for encryption type`, try updating the global crypto policy to allow older encryption algorithms:

```
[user@host ~]$ sudo update-crypto-policies --set DEFAULT:AD-SUPPORT
```

If this process succeeds, you should now be able to pull `passwd` information for an Active Directory user.

```
[user@host ~]$ sudo getent passwd administrator@ad.company.local
administrator@ad.company.local:*:1450400500:1450400513:Administrator:/home/administrator@ad.company.local:/bin/bash
```

If we'd like to omit domain name for AD user, configure like follows:

```
[root@dlp ~]# vi /etc/sssd/sssd.conf

# line 16 : change
use_fully_qualified_names = False

[root@dlp ~]# systemctl restart sssd

[root@dlp ~]# id Administrator
uid=691200500(administrator) gid=691200513(domain users) groups=691200513(domain users),691200572(denied rodc password replication group),691200519(enterprise admins),691200512(domain admins),691200518(schema admins),691200520(group policy creator owners)
```

`  Login through the users that are in the AD in Linux System in tty`

OR 

### Attempting to Authenticate

Now your users should be able to authenticate to your Linux host against Active Directory.
**On Windows 10:** (which provides its own copy of OpenSSH)

```
C:\Users\John.Doe> ssh -l john.doe@ad.company.local linux.host
Password for john.doe@ad.company.local:

Activate the web console with: systemctl enable --now cockpit.socket

Last login: Wed Sep 15 17:37:03 2021 from 10.0.10.241
[john.doe@ad.company.local@host ~]$
```

If this succeeds, you have successfully configured Linux to use Active Directory as an authentication source.


**AD users UID/GID are asigned randomly, but if we'd like to asign fixed UID/GID, configure like follows.**

[Add UNIX attributes to AD accounts first, refer to here](https://www.server-world.info/en/note?os=Windows_Server_2019&p=active_directory&f=12).  
( To add them by PowerShell on CUI, refer to here of [4] )  
This example is based on the environment AD accounts have [uidNumber/gidNumber] attributes.

Next, change SSSD settings.

```
[root@dlp ~]# vi /etc/sssd/sssd.conf

# line 15 : change
ldap_id_mapping = False

# add to the end  
ldap_user_uid_number = uidNumber  
ldap_user_gid_number = gidNumber

# clear cache and restart sssd
  
[root@dlp ~]# rm -f /var/lib/sss/db/*

  
[root@dlp ~]# systemctl restart sssd

[root@dlp ~]# id serverworld
uid=5000(serverworld) gid=5000(linuxgroup) groups=5000(linuxgroup)
```

### Setting the default domain

In a completely default setup, you will need to log in with your AD account by specifying the domain in your username (e.g. `john.doe@ad.company.local`). If this is not the desired behaviour, and you instead want to be able to omit the domain name at authentication time, you can configure SSSD to default to a specific domain.

This is actually a relatively simple process, and just requires a configuration tweak in your SSSD configuration file.

```
[user@host ~]$ sudo vi /etc/sssd/sssd.conf
[sssd]
...
default_domain_suffix = ad.company.local
```

By adding the `default_domain_suffix`, you are instructing SSSD to (if no other domain is specified) infer that the user is trying to authenticate as a user from the `ad.company.local` domain. This allows you to authenticate as something like `john.doe` instead of `john.doe@ad.company.local`.

To make this configuration change take effect, you must restart the `sssd.service` unit with `systemctl`.
```
[user@host ~]$ sudo systemctl restart sssd
```


