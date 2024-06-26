{ desktop, hostname, lib, pkgs, username, ... }:
let
  defaultDns = [ "1.1.1.1" "1.0.0.1" ];
  # https://nixos.wiki/wiki/Steam
  isGamestation = if (hostname == "phasma" || hostname == "vader") && (desktop != null) then true else false;
  isInstall = if (builtins.substring 0 4 hostname != "iso-") then true else false;
  hasRazerPeripherals = if (hostname == "phasma" || hostname == "vader") then true else false;
  needsLowLatencyPipewire = if (hostname == "phasma" || hostname == "vader") then true else false;
  saveBattery = if (hostname != "phasma" && hostname != "vader") then true else false;

  # Define DNS settings for specific users
  # - https://cleanbrowsing.org/filters/
  userDnsSettings = {
    # Security Filter:
    # - Blocks access to phishing, spam, malware and malicious domains.
    martin = [ "185.228.168.9" "185.228.169.9" ];

    # Adult Filter:
    # - Blocks access to all adult, pornographic and explicit sites.
    # - It does not block proxy or VPNs, nor mixed-content sites.
    # - Sites like Reddit are allowed.
    # - Google and Bing are set to the Safe Mode.
    # - Malicious and Phishing domains are blocked.
    louise = [ "185.228.168.10" "185.228.169.11" ];

    # Family Filter:
    # - Blocks access to all adult, pornographic and explicit sites.
    # - It also blocks proxy and VPN domains that are used to bypass the filters.
    # - Mixed content sites (like Reddit) are also blocked.
    # - Google, Bing and Youtube are set to the Safe Mode.
    # - Malicious and Phishing domains are blocked.
    agatha = [ "185.228.168.168" "185.228.169.168" ];
  };
in
{
  imports = [
    ./features/flatpak
    ./apps/chromium
    ./apps/firefox
    ./apps/obs-studio
  ] ++ lib.optional (builtins.pathExists (./. + "/${desktop}")) ./${desktop};

  boot = {
    # Enable the threadirqs kernel parameter to reduce audio latency
    # - Inpired by: https://github.com/musnix/musnix/blob/master/modules/base.nix#L56
    kernelParams = [ "quiet" "vt.global_cursor_default=0" "mitigations=off" "threadirqs" ];
    plymouth = {
      catppuccin.enable = if (username == "martin") then true else false;
      enable = true;
    };
  };

  environment.etc = {
    "backgrounds/DeterminateColorway-1920x1080.png".source = ../configs/backgrounds/DeterminateColorway-1920x1080.png;
    "backgrounds/DeterminateColorway-1920x1200.png".source = ../configs/backgrounds/DeterminateColorway-1920x1200.png;
    "backgrounds/DeterminateColorway-2560x1440.png".source = ../configs/backgrounds/DeterminateColorway-2560x1440.png;
    "backgrounds/DeterminateColorway-3440x1440.png".source = ../configs/backgrounds/DeterminateColorway-3440x1440.png;
    "backgrounds/DeterminateColorway-3840x2160.png".source = ../configs/backgrounds/DeterminateColorway-3840x2160.png;
  };

  environment.systemPackages = with pkgs; [
    catppuccin-cursors.mochaBlue
    (catppuccin-gtk.override {
      accents = [ "blue" ];
      size = "standard";
      variant = "mocha";
    })
    (catppuccin-papirus-folders.override {
      flavor = "mocha";
      accent = "blue";
    })
  ] ++ lib.optionals (isInstall) [
    appimage-run
    pavucontrol
    pulseaudio
    wmctrl
    xdotool
    ydotool
  ] ++ lib.optionals (isGamestation) [
    mangohud
  ] ++ lib.optionals (isInstall && hasRazerPeripherals) [
    polychromatic
  ];

  fonts = {
    # Enable a basic set of fonts providing several font styles and families and reasonable coverage of Unicode.
    enableDefaultPackages = false;
    fontDir.enable = true;
    packages = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" "NerdFontsSymbolsOnly" ]; })
      fira
      liberation_ttf
      noto-fonts-emoji
      source-serif
      twitter-color-emoji
      work-sans
    ] ++ lib.optionals (isInstall) [
      ubuntu_font_family
    ];

    fontconfig = {
      antialias = true;
      cache32Bit = isGamestation;
      defaultFonts = {
        serif = [ "Source Serif" ];
        sansSerif = [ "Work Sans" "Fira Sans" ];
        monospace = [ "FiraCode Nerd Font Mono" "Symbols Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" "Twitter Color Emoji" ];
      };
      enable = true;
      hinting = {
        autohint = false;
        enable = true;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "light";
      };
    };
  };

  networking = {
    networkmanager = {
       dns = "systemd-resolved";
      enable = true;
      # Conditionally set Public DNS based on username, defaulting if user not matched
      insertNameservers = if builtins.hasAttr username userDnsSettings then
                            userDnsSettings.${username}
                          else
                            defaultDns;
      wifi = {
        backend = "iwd";
        powersave = saveBattery;
      };
    };
  };

  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = isGamestation;
    };
    openrazer = lib.mkIf (hasRazerPeripherals) {
      enable = true;
      devicesOffOnScreensaver = false;
      keyStatistics = true;
      mouseBatteryNotifier = true;
      syncEffectsEnabled = true;
      users = [ "${username}" ];
    };
    pulseaudio.enable = lib.mkForce false;
    sane = lib.mkIf (isInstall) {
      enable = true;
      #extraBackends = with pkgs; [ hplipWithPlugin sane-airscan ];
      extraBackends = with pkgs; [ sane-airscan ];
    };
  };

  programs = {
    appimage.binfmt = true;
    steam = lib.mkIf (isGamestation) {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
    system-config-printer = lib.mkIf (isInstall) {
      enable = if (desktop == "mate") then true else false;
    };
  };

  services = {
    # https://nixos.wiki/wiki/PipeWire
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
    # Debugging
    #  - pw-top                                            # see live stats
    #  - journalctl -b0 --user -u pipewire                 # see logs (spa resync is "bad")
    #  - pw-metadata -n settings 0                         # see current quantums
    #  - pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
    #  - pw-metadata -n settings 0 clock.force-quantum 0   # disable override
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = isGamestation;
      jack.enable = false;
      pulse.enable = true;
      wireplumber = {
        enable = true;
        # https://stackoverflow.com/questions/24040672/the-meaning-of-period-in-alsa
        # https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html#alsa-buffer-properties
        # cat /nix/store/*-wireplumber-*/share/wireplumber/main.lua.d/99-alsa-lowlatency.lua
        # cat /nix/store/*-wireplumber-*/share/wireplumber/wireplumber.conf.d/99-alsa-lowlatency.conf
        configPackages = lib.mkIf (needsLowLatencyPipewire) [
          (pkgs.writeTextDir "share/wireplumber/main.lua.d/99-alsa-lowlatency.lua" ''
              alsa_monitor.rules = {
                {
                  matches = {{{ "node.name", "matches", "*_*put.*" }}};
                  apply_properties = {
                    ["audio.format"] = "S16LE",
                    ["audio.rate"] = 48000,
                    -- api.alsa.headroom: defaults to 0
                    ["api.alsa.headroom"] = 128,
                    -- api.alsa.period-num: defaults to 2
                    ["api.alsa.period-num"] = 2,
                    -- api.alsa.period-size: defaults to 1024, tweak by trial-and-error
                    ["api.alsa.period-size"] = 512,
                    -- api.alsa.disable-batch: USB audio interface typically use the batch mode
                    ["api.alsa.disable-batch"] = false,
                    ["resample.quality"] = 4,
                    ["resample.disable"] = false,
                    ["session.suspend-timeout-seconds"] = 0,
                  },
                },
              }
            '')
        ];
      };
      # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
      extraConfig.pipewire."92-low-latency" = lib.mkIf (needsLowLatencyPipewire) {
        "context.properties" = {
          "default.clock.rate"          = 48000;
          "default.clock.quantum"       = 64;
          "default.clock.min-quantum"   = 64;
          "default.clock.max-quantum"   = 64;
        };
        "context.modules" = [{
          name = "libpipewire-module-rt";
          args = {
            "nice.level" = -11;
            "rt.prio" = 88;
          };
        }];
      };
      extraConfig.pipewire-pulse."92-low-latency" = lib.mkIf (needsLowLatencyPipewire) {
        "pulse.properties" = {
          "pulse.default.format" = "S16";
          "pulse.fix.format" = "S16LE";
          "pulse.fix.rate" = "48000";
          "pulse.min.frag" = "64/48000";      # 1.3ms
          "pulse.min.req" = "64/48000";       # 1.3ms
          "pulse.default.frag" = "64/48000";  # 1.3ms
          "pulse.default.req" = "64/48000";   # 1.3ms
          "pulse.max.req" = "64/48000";       # 1.3ms
          "pulse.min.quantum" = "64/48000";   # 1.3ms
          "pulse.max.quantum" = "64/48000";   # 1.3ms
        };
        "stream.properties" = {
          "node.latency" = "64/48000";        # 1.3ms
          "resample.quality" = 4;
          "resample.disable" = false;
        };
      };
    };
    printing = lib.mkIf (isInstall) {
      enable = true;
      drivers = with pkgs; [ gutenprint hplip ];
    };
    system-config-printer.enable = isInstall;

    # Provides users with access to all Elgato StreamDecks.
    # https://github.com/muesli/deckmaster
    # https://gitlab.gnome.org/World/boatswain/-/blob/main/README.md#udev-rules
    udev.extraRules = ''
      # Deckmaster needs write access to uinput to simulate keypresses.
      # Users wanting to use Deckmaster should be added to the input group.
      KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput", GROUP="input", MODE="0660"

      # Elgato Stream Deck Mini
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", TAG+="uaccess", SYMLINK+="streamdeck-mini"

      # Elgato Stream Deck Mini (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", TAG+="uaccess", SYMLINK+="streamdeck-mini"

      # Elgato Stream Deck Original
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck Original (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck MK.2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", TAG+="uaccess", SYMLINK+="streamdeck"

      # Elgato Stream Deck XL
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", TAG+="uaccess", SYMLINK+="streamdeck-xl"

      # Elgato Stream Deck XL (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="008f", TAG+="uaccess", SYMLINK+="streamdeck-xl"

      # Elgato Stream Deck Pedal
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", TAG+="uaccess", SYMLINK+="streamdeck-pedal"

      # Expose important timers the members of the audio group
      # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L94
      KERNEL=="rtc0", GROUP="audio"
      KERNEL=="hpet", GROUP="audio"
      # Allow users in the audio group to change cpu dma latency
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
    '';

    # Disable xterm
    xserver = {
      desktopManager.xterm.enable = false;
      # Disable autoSuspend; my Pantheon session kept auto-suspending
      # - https://discourse.nixos.org/t/why-is-my-new-nixos-install-suspending/19500
      displayManager.gdm.autoSuspend = if (desktop == "pantheon") then true else false;
      excludePackages = [ pkgs.xterm ];
    };
  };

  security = {
    # Allow members of the "audio" group to set RT priorities
    # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L87
    pam.loginLimits = [
      { domain = "@audio"; item = "memlock"; type = "-"   ; value = "unlimited"; }
      { domain = "@audio"; item = "rtprio" ; type = "-"   ; value = "99"       ; }
      { domain = "@audio"; item = "nofile" ; type = "soft"; value = "99999"    ; }
      { domain = "@audio"; item = "nofile" ; type = "hard"; value = "99999"    ; }
    ];
    rtkit.enable = true;
  };

  systemd.services = {
    disable-wifi-powersave = lib.mkIf (!saveBattery) {
      wantedBy = ["multi-user.target"];
      path = [ pkgs.iw ];
      script = ''
        iw dev wlan0 set power_save off
      '';
    };
  };

  xdg.portal = {
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
    enable = true;
    xdgOpenUsePortal = true;
  };
}
