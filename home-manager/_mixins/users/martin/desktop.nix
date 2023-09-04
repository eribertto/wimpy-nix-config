{ lib, username, ... }:
with lib.hm.gvariant;
{
  imports = [
    ../../desktop/audio-recorder.nix
    ../../desktop/celluloid.nix
    ../../desktop/dconf-editor.nix
    ../../desktop/emote.nix
    ../../desktop/gitkraken.nix
    ../../desktop/gnome-sound-recorder.nix
    ../../desktop/meld.nix
    ../../desktop/rhythmbox.nix
    ../../desktop/tilix.nix
  ];
  
  dconf.settings = {
    "org/gnome/rhythmbox/rhythmdb" = {
      locations = [ "file:///home/${username}/Studio/Music" ];
      monitor-library = true;
    };
  };
}
