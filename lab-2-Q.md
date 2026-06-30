# Lab 1: Configure Yum Repository

Configure Yum repositories on all managed nodes with the following details:

## Requirements

### Repository 1

- **Name:** baseos  
- **Description:** Baseos Description  
- **Base URL:** http://ec2-100-48-11-172.compute-1.amazonaws.com/BaseOS/  
- **GPG Check:** Enabled  
- **GPG Key:** http://ec2-100-48-11-172.compute-1.amazonaws.com/RPM-GPG-KEY-redhat-release  
- **State:** Enabled  

---

### Repository 2

- **Name:** appstream  
- **Description:** appstream Description  
- **Base URL:** http://ec2-100-48-11-172.compute-1.amazonaws.com/AppStream/  
- **GPG Check:** Enabled  
- **GPG Key:** http://ec2-100-48-11-172.compute-1.amazonaws.com/RPM-GPG-KEY-redhat-release  
- **State:** Enabled  
``
