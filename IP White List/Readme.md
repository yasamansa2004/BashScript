This project modifies your firewall configuration to allow ArvanCloud's CDN network access to your server.

You can also schedule this script to update the firewall rules automatically.

[](#how-to-use)How to use
-------------------------

Just run the script and select your firewall from the list:

    Select a firewall to add IPs:
       1) UFW
       2) CSF
       3) firewalld
       4) iptables
       5) ipset+iptables
       6) nftables
    Firewall:

And you can choose `IPv4` or `IPv4 + IPv6`:

    Select IP version:
       1) IPv4
       2) IPv4 + IPv6
    Version:

Also, you can pass inputes as arguments:

    bash ar-whitelister.sh ufw v4
    bash ar-whitelister.sh iptables v4v6

### [](#auto-update)Auto-update

You can create a cronjob to update the rules automatically.

Examples:

*   Update UFW rules for IPv4 every 6 hours
    
        0 */6 * * * /path/to/ar-whitelister.sh ufw v4 >/dev/null 2>&1
    
*   Update CSF rules for both IPv4 and IPv6 every day at 1:00
    
        0 1 * * * /path/to/ar-whitelister.sh csf v4v6 >/dev/null 2>&1
    

[](#supported-firewalls)Supported firewalls
-------------------------------------------

We currently support these firewalls:

*   UFW
*   CSF
*   firewalld
*   iptables
*   ipset+iptables
*   nftables