{ config, inputs, lib, pkgs, platform, username, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./disks-home.nix
    ./disks-snapshot.nix
    ../_mixins/services/clamav.nix
    ../_mixins/services/filesync.nix
    ../_mixins/services/caddy
    ../_mixins/services/homepage
    ../_mixins/services/tailscale
  ];

  # TODO: Remove this if/when machine is reinstalled.
  # This is a workaround for the legacy -> gpt tables disko format.
  fileSystems = {
    "/".device = lib.mkForce "/dev/disk/by-partlabel/root";
    "/boot".device = lib.mkForce "/dev/disk/by-partlabel/ESP";
  };

  boot = {
    blacklistedKernelModules = lib.mkDefault [ "nouveau" ];
    initrd.availableKernelModules = [ "nvme" "ahci" "xhci_pci" "usbhid" "uas" "sd_mod" ];
    kernelModules = [ "amdgpu" "kvm-amd" "nvidia" ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
    # Disable USB autosuspend on workstations
    kernelParams = [ "usbcore.autosuspend=-1" ];
    swraid = {
      enable = true;
      mdadmConf = "PROGRAM=true";
    };
  };

  hardware = {
    mwProCapture.enable = true;
    nvidia = {
      package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;
      prime = {
        amdgpuBusId = "PCI:33:0:0";
        nvidiaBusId = "PCI:30:0:0";
        # Make the Radeon RX6700 XT default; the NVIDIA T1000 is for CUDA/NVENC
        reverseSync.enable = true;
      };
      nvidiaSettings = false;
    };
  };

  # Adjust MTU for Virgin Fibre
  # - https://search.nixos.org/options?channel=23.11&show=networking.networkmanager.connectionConfig&from=0&size=50&sort=relevance&type=packages&query=networkmanager
  networking.networkmanager.connectionConfig = {
    "ethernet.mtu" = 1462;
    "wifi.mtu" = 1462;
  };

  programs.corectrl = {
    enable = true;
    gpuOverclock.enable = true;
  };

  services = {
    cron = {
      enable = true;
      systemCronJobs = [
        "*/30 * * * * ${username} /home/${username}/Scripts/backup/sync-legoworlds.sh >> /home/${username}/Games/Steam_Backups/legoworlds.log"
        "42 * * * * ${username} /home/${username}/Scripts/backup/sync-hotshotracing.sh >> /home/${username}/Games/Steam_Backups/hotshotracing.log"
      ];
    };
    udev.extraRules = ''
      # Remove NVIDIA Audio devices, if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
    '';
    xserver.videoDrivers = [ "amdgpu" "nvidia" ];
  };
}
