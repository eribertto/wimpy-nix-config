{ desktop, lib, pkgs, ... }: {
  imports = [
    ../services/cups.nix
  ]
  ++ lib.optional (builtins.pathExists (./. + "/${desktop}.nix")) ./${desktop}.nix;

  boot = {
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" ];
    plymouth.enable = true;
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
    };
  };

  programs.dconf.enable = true;

  # Disable xterm
  services.xserver.excludePackages = [ pkgs.xterm ];
  services.xserver.desktopManager.xterm.enable = false;

  systemd.services.disable-wifi-powersave = {
    wantedBy = ["multi-user.target"];
    path = [ pkgs.iw ];
    script = ''
      iw dev wlan0 set power_save off
    '';
  };

  xdg.portal = {
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
      pantheon = {
        default = [
          "pantheon"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [
          "gnome-keyring"
        ];
      };
    };
    enable = true;
    xdgOpenUsePortal = true;
  };
}
