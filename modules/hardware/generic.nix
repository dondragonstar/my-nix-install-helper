# Guaranteed-boot floor: kernel modesetting only, no vendor driver.
# Selected when GPU detection fails or finds an unknown vendor.
# The system boots to a working desktop; pick a real profile in
# machine.nix later and rebuild.
{ machine, ... }:

{
}
