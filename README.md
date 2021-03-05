# Privacy Stack Setup
---------------------

I wanted more control of my information and for big companies to have less insight into what I did online for privacy (emails, files, chat, video, etc.). These Ansible playbooks deploy many open source tools that allow you to self-host many common services, including:

| Role       | Provider     | URL     |
| :------------- | :---------- | :----------- |
| VPN | Wireguard | https://www.wireguard.com/
| Mail | Docker-Mailserver | https://github.com/tomav/docker-mailserver |
| Webserver | Nginx  | https://nginx.org/ | 
| Certificates | LetsEncrypt  | https://letsencrypt.org/ | 
| Authentication | OpenLDAP  | https://www.openldap.org/ | 
| Database | Postgres  | https://www.postgresql.org/ | 
| File Storage, Contacts, and Calendar | Nextcloud  | https://nextcloud.com/ | 
| Chat | Element  | https://element.io/ | 
| Password Management | Bitwarden  | https://github.com/dani-garcia/bitwarden_rs | 
| DNS | Pi-hole  | https://pi-hole.net/ | 
| Logging | Elastic Auditbeat  | https://www.elastic.co/beats/auditbeat | 
| Git | Gitea  | https://gitea.io/ | 
  
### Supporting Toolsets
| Role       | Provider     | URL     |
| :------------- | :---------- | :----------- |
| Notes | Joplin  | https://joplinapp.org/ | 
| Browser | Brave  | https://brave.com/ | 
| Containers | Docker | https://www.docker.com/ | 
| Container Upgrades | Watchtower | https://containrrr.dev/watchtower/ |
| Deployment Automation | Ansible | https://www.ansible.com/ | 
| Certificate Renewals | Acme Tiny | https://github.com/diafygi/acme-tiny |  

Many thanks to all the people who have contributed to the awesome open source projects used for this project. Without their contributions this project would not be possible.

**Important Notes**:
1. There is a bug with SSL Certificate renewals that occasionally (reason still unknown) can overwrite the root LetsEncrypt .pem with an empty file. Quick fix is the copy the contents of the `<domain>-fullchain.crt` certificate to the .pem file and restart the server. 
2. If Postgrey is enabled on your mailserver instance (the default) it will cause emails from previously unknown IPs to be delayed 5 minutes. This prevents a lot of spam but also is important to know if you are waiting on a email and it isn't showing up immediately. See mail section in `site.yml` to disable Postgrey. 
3. Automatic upgrade of containers via Watchtower are disabled. This occasionally broke things. Need to come up with better way up upgrading but not breaking functionality. If you want to force automatic upgrades you can change update the `com.centurylinklabs.watchtower.enable` variable from `false` to `true` on any desired container. 

## Deployment
1. This has only been tested and deployed on: 
    - `CentOS Linux release 8.2.2004 (Core)` 
    - `Ubuntu 20.04.1 LTS (GNU/Linux 5.4.0-1032-aws x86_64)`
2. Modify the `hosts` file to point to the destination host you want to deploy to.
3. Ensure firewall rules are in place on the destination host to allow connections to:
    - `tcp/22 (SSH)`
    - `tcp/25 (SMTP)`
    - `tcp/80 (HTTP)`
    - `tcp/143 (IMAP)`
    - `tcp/443 (HTTPS)`
    - `tcp/587 (SMTP MTA)`
    - `tcp/993 (IMAPS)`
    - `udp/500 (VPN)`
4. Modify the `site.yml` to enter the relevant domain name, folder names, ethernet interface information, etc.
5. Ensure you can use SSH keys to login to destination host without any prompts and the destination user is root or has sudo rights. 
6. Modify the `users.yml` information with appropriate user information (names, IDs, passwords, etc.).
7. Ensure ansible is installed on your deployment system.
8. Ensure appropriate DNS records are in place for your deployment (screenshot with DNS records below). Default domains used by these playbooks are:
    - `<domain.com>`
    - `www.<domain.com>`
    - `mail.<domain.com>`
    - `vpn.<domain.com>`
    - `vault.<domain.com>`
    - `drive.<domain.com>`
    - `chat.<domain.com>`
    - `x.<domain.com>`
    - `git.<domain.com>`  
8. Execute `ansible-playbook -i hosts site.yml`
9. All relevant output (passwords, VPN profiles, etc.) will be saved to the `support_material` directory in appropriate directories. 

## Helpful Commands
#### Backup Process  

**Backs up selected files to local folder**  
`ansible-playbook -i hosts site.yml --tags "backup"`

#### Create User Account(s)
`ansible-playbook -i hosts site.yml --tags "account_create"`

#### Reset User Password
`ansible-playbook -i hosts site.yml --tags "password_change" --extra-vars "password_change_user=us◊er.name password_change_password=<password>" `
◊
#### Disable User Account
`ansible-playbook -i hosts site.yml --tags "account_disable" --extra-vars "account_disable=<name_of_account_to_disable>"`

#### Add local Matrix/Element User (run from destination host command line)
`docker exec -it chat-server /usr/local/bin/register_new_matrix_user -u <user.name> -p <password> --no-admin -c /data/homeserver.yaml <https://x.site.com>`

## DNS Records  
![DNS Records](/images/dns_records.png)

###  DNS Records For Mail (DKIM/SPF/DMARC)
| Type | Name/Host | Value | Security Mechanism |
| ---- |---------- | ----- | ------------------ |
| TXT | @ | v=spf1 mx ~all | SPF |
| TXT | mail._domainkey | v=DKIM1;h=sha256;k=rsa;p=MIIB ...snip... QAB | DKIM |
| TXT | _dmarc | v=DMARC1;p=quarantine;sp=quarantine;pct=100;rua=mailto:dmarcreports@your.domain.name; | DMARC |

**NOTE**: Value for DKIM TXT record should be located at `/<root_path>/mail/config/opendkim/keys/<domain.com>/mail.txt` on the target host.

## To Do 
--------
  - Add Path To Seamlessly Upgrade Without Breaking Functionality
  - External Storage Automation & Encryption
  - Better Error Handling
  - Improve Account Disable Functionality
  - Better Account Creation Control
  - Enable Support For Multiple Domains

## Completed To Do Items
------------------------
  - ~~Certificate Renewal~~
  - ~~Email Alias'~~
  - ~~VPN~~
  - ~~Web~~
  - ~~OS Update~~
  - ~~Logging~~
  - ~~DNS~~
  - ~~Password Generation~~
  - ~~Password Change for Existing User~~
  - ~~Contacts~~ 
  - ~~Calendar~~
  - ~~Add Users~~
  - ~~Disable/Remove Users~~ 
  - ~~Backup~~
  - ~~Review~~
  - ~~Documentation~~
  - ~~Fix Nextcloud Contact Sync~~

## Issues
------------------------
  - 20200902 - Server cert (/privacy/letsencrypt/certs/domain.com) was empty, but still existed.
  - 20201002 - /etc/hosts file in webmail container (Roundcube) was incorrect, didn't parse jinja variable correctly 
  - 20201002 - Roundcube/mailserver needed full chain certificate instead of just the server certificate in order to send mail (receive and login worked ok).

## Notes
------------------------ 
#### MacOS Calendar Sync
- Create App Password in Nextcloud  
- "Add a CalDAV account" in MacOS (Catalina).   
  - Account Type: Manual  
  - Username: user.name    
  - Password: App Password   
- Server Address: https://drive.domain.com/remote.php/dav/principals/users/user.name/  

**NOTE**: As of Nextcloud 20.x, the CalDAV path is no longer needed for MacOS, you can go to manual, user the username, app password, and the domain (do not have to specify /remote.php/dav/principals/users/user.name anymore).  

#### MacOS Contacts Sync 
- Use previously generated App Password from Nextcloud (or create a new one)  
- "Add a CardDAV account" in MacOS (Catalina).  
  - Account Type: Manual  
  - Username: user.name   
  - Password: App Password   
  - Server Address: https://drive.domain.com/  

(c) Joshua Smith - 2021