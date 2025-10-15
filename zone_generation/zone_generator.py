import ipaddress
import random
import string

HEADER = """$TTL 3600
@   IN  SOA ns1.wi.lan. admin.wi.lan. (
            2025101410 ; serial (YYYYMMDDnn)
            3600       ; refresh
            1800       ; retry
            604800     ; expire
            3600 )     ; minimum

    IN  NS  ns1.wi.lan.
ns1     IN  A 10.10.2.2
"""
SLD = "wi.lan"
#Should be a subnet using CIDR notation
SUBNET = "10.10.16.0/20"

def get_random_hostnames(count: int, length: int = 8) -> set(str):
    # Use a set to ensure uniqueness
    hostnames = set()
    while len(hostnames) < count:
        hostname = ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))
        hostnames.add(hostname)
    return hostnames

def generate_random_fqdns_and_ips(subnet: str, sld: str, count: int = None):
    """
    Generate unique random FQDNs and IPs within a given subnet.
    
    Args:
        subnet (str): CIDR subnet (e.g., '192.168.1.0/24')
        sld (str): second-level domain (e.g., 'wi.lan')
    
    Returns:
        list of tuples: [(fqdn, ip), ...]
    """
    net = ipaddress.ip_network(subnet, strict=False)
    all_ips = list(net.hosts())
    if count is None:
        count = len(all_ips)

    hostnames = get_random_hostnames(count)
    # Pair each unique random hostname with an IP
    if count == len(all_ips):
        fqdn_ip_pairs = [(f"{hostname}.{sld}", str(ip)) for hostname, ip in zip(hostnames, all_ips)]
        random.shuffle(fqdn_ip_pairs)  # randomize final output order
    else:
        ips = random.choices(all_ips, k = count)
        fqdn_ip_pairs = [(f"{hostname}.{sld}", str(ip)) for hostname, ip in zip(hostnames, ips)]
    return fqdn_ip_pairs

def get_dnsperf_entry(fqdn):
    return f"{fqdn}.  A\n"
def get_zone_file_entry(fqdn, ip):
    return f"{fqdn}.  IN  A {ip}\n"

# Example usage
if __name__ == "__main__":
    pairs = generate_random_fqdns_and_ips(SUBNET, SLD)
    with open("zone_file", 'w') as f:
        f.write(HEADER)
        for fqdn, ip in pairs:
            f.write(get_zone_file_entry(fqdn, ip))
    with open("dnsperf_input", 'w') as f:
        for fqdn, _ in pairs:
            f.write(get_dnsperf_entry(fqdn))
    print(f"Created {len(pairs)} domain/ips")