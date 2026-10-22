self:
{ pkgs, lib, ... }:
{
  imports = [ ./hm/kmusic.nix ];
  programs.kmusic.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.default;
}
