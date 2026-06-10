  network:
    network:
      version: 2
      ethernets:
%{ if ip != null ~}
        ${device}:
          dhcp4: false
          addresses:
            - ${ip}/${netmask}
          routes:
            - to: default
              via: ${gateway}
          nameservers:
            addresses:
%{ for item in dns ~}
              - ${item}
%{ endfor ~}
%{ else ~}
        # ${device} is a netplan ID here, not an interface name: the guest's
        # predictable name follows the virtual hardware's PCI slot (observed
        # ens33 via ethernet0.pciSlotNumber = 33, not the ens192 default), so
        # match any en* interface instead of pinning a name.
        ${device}:
          match:
            name: en*
          dhcp4: true
%{ endif ~}
