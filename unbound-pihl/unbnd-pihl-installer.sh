#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

LOG_FILE="/var/log/pihole_unbound_install.log"
> "$LOG_FILE" # Clear log file

# Function to log errors
log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Check for appropriate elevated privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Function to confirm with yes/no
confirm() {
    while true; do
        read -rp "$1 (y/n): " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Update the system
if confirm "Do you want to update system packages?"; then
    echo "Updating system packages..."
    apt update && apt upgrade -y || log_error "Failed to update system packages."
fi

# Install dependencies
if confirm "Do you want to install necessary dependencies?"; then
    echo "Installing dependencies..."
    apt install -y curl unbound unbound-host || log_error "Failed to install dependencies."
fi

# Install Pi-hole
if confirm "Do you want to install Pi-hole?"; then
    echo "Installing Pi-hole..."
    curl -sSL https://install.pi-hole.net | bash || log_error "Failed to install Pi-hole."
fi

# Configure Unbound
if confirm "Do you want to configure Unbound for recursive DNS resolution?"; then
    echo "Configuring Unbound..."
    cat <<EOF > /etc/unbound/unbound.conf.d/pi-hole.conf
 server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 0

    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

     # May need to adjust access-control if not default local-only
    access-control: 127.0.0.0/8 allow

     # Perform DNSSEC validation
    auto-trust-anchor-file: "/var/lib/unbound/root.key"

    # May be set to yes if you have IPv6 connectivity
    do-ip6: no

    # You want to leave this to no unless you have *native* IPv6. With 6to4 and
    # Terredo tunnels your web browser should favor IPv4 for the same reasons
    prefer-ip6: no

    # Use this only when you downloaded the list of primary root servers!
    # If you use the default dns-root-data package, unbound will find it automatically
    #root-hints: "/var/lib/unbound/root.hints"

    # Trust glue only if it is within the server's authority
    harden-glue: yes

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
    harden-dnssec-stripped: yes

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size.
    # IP fragmentation is unreliable on the Internet today, and can cause
    # transmission failures when large DNS messages are sent via UDP. Even
    # when fragmentation does work, it may not be secure; it is theoretically
    # possible to spoof parts of a fragmented DNS message, without easy
    # detection at the receiving end. Recently, there was an excellent study
    # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
    # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
    # in collaboration with NLnet Labs explored DNS using real world data from the
    # the RIPE Atlas probes and the researchers suggested different values for
    # IPv4 and IPv6 and in different scenarios. They advise that servers should
    # be configured to limit DNS messages sent over UDP to a size that will not
    # trigger fragmentation on typical network links. DNS servers can switch
    # from UDP to TCP when a DNS response is too big to fit in this limited
    # buffer size. This value has also been suggested in DNS Flag Day 2020.
    edns-buffer-size: 1232

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes

    # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
    num-threads: 1

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

    # Minimize any data leakage by using minimal responses
    minimal-responses: yes
    # Cache settings
    cache-min-ttl: 3600
    cache-max-ttl: 86400 

    # Ensure privacy of local IP ranges
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
EOF
    systemctl enable unbound || log_error "Failed to enable Unbound."
    systemctl start unbound || log_error "Failed to start Unbound."
fi

# Test validation
if confirm "Do you want to test validation?"; then
    echo "Testing validation..."
    dig pi-hole.net @127.0.0.1 -p 5335 || log_error "Failed validation."



# Update Pi-hole's DNS settings
if confirm "Do you want to configure Pi-hole to use Unbound?"; then
    echo "Configuring Pi-hole to use Unbound..."
    echo "PIHOLE_DNS_1=127.0.0.1#5335" >> /etc/pihole/setupVars.conf || log_error "Failed to update Pi-hole DNS settings."
    pihole restartdns || log_error "Failed to restart Pi-hole DNS."
fi

# Disable resolvconf settings for Unbound if Debian Bullseye+
if confirm "Do you want to disable resolvconf settings for Unbound (Debian Bullseye+)?"; then
    if grep -q "bullseye" /etc/os-release; then
        echo "Disabling resolvconf settings for Unbound..."
        sudo systemctl disable --now unbound-resolvconf.service || log_error "Failed to disable unbound-resolvconf.service."
        sudo sed -Ei 's/^unbound_conf=/#unbound_conf=/' /etc/resolvconf.conf || log_error "Failed to disable unbound_conf in resolvconf.conf."
        sudo rm -f /etc/unbound/unbound.conf.d/resolvconf_resolvers.conf || log_error "Failed to remove resolvconf_resolvers.conf."
        systemctl restart unbound || log_error "Failed to restart Unbound."
    fi
fi

# Create update script
if confirm "Do you want to create a script for updating Pi-hole?"; then
    echo "Creating update script..."
    cat <<EOF > /usr/local/bin/update_pihole
#!/bin/bash
pihole -up
apt update && apt upgrade -y
EOF
    chmod +x /usr/local/bin/update_pihole
fi

echo "Installation script completed. Check $LOG_FILE for any errors."
