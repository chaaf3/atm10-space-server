# ATM10 + Space Server Deploy Kit

This folder sets up an **All the Mods 10** server with a compatible space mod layered on top.

As of May 29, 2026, ATM10 is on **Minecraft 1.21.1** with **NeoForge**. That means we should not try to merge in a whole random space modpack unless it targets the exact same game version and loader. The safer route is ATM10 plus individual compatible mods.

Chosen space stack:

- `Stellaris` for rockets, planets, moons, galaxies, and space progression.
- `Potentials`, required by Stellaris.
- `Architectury API`, required by Stellaris, but skipped if ATM10 already includes it.

`Ad Astra` is the familiar space mod, but its public CurseForge releases are not currently a clean ATM10 fit because they target older Minecraft versions.

## Recommended Hosting

The Terraform target here uses AWS because it is straightforward to automate and easy to move later. For a first server, use:

- `m7a.xlarge`: 4 vCPU, 16 GB RAM, good for a small friend group.
- `m7a.2xlarge`: 8 vCPU, 32 GB RAM, better for a busier world or heavy automation.
- `150 GB gp3` disk minimum.

Cheaper alternatives:

- Oracle Cloud Ampere can be inexpensive, but ARM sometimes adds modded-Minecraft surprises.
- Hetzner is often the best price/performance if you are okay using a VPS provider instead of the big clouds.
- GCP/Azure are fine with an equivalent 4 vCPU/16 GB or 8 vCPU/32 GB VM.

## Oracle Cloud Deploy

Recommended Oracle starting point for 6-10 players:

- Shape: `VM.Standard.A1.Flex`
- CPU/RAM: `6 OCPU`, `48 GB RAM`
- Disk: `500 GB` boot volume
- JVM heap: `16G` minimum, `20G` maximum

This is the fixed Scale 1 setup. The Terraform variables include guardrails that reject plans above or below `6 OCPU`, `48 GB RAM`, and `500 GB` disk unless you deliberately edit those guardrails. There is no autoscaling group, instance pool, or scheduled scaling in this deployment. It should land around `$43-$49/month` before taxes/region differences, assuming your account gets the normal Always Free allowance for A1 compute and the first 200 GB of block storage.

Install OpenTofu and OCI CLI, then create/upload an OCI API signing key:

```bash
brew install opentofu oci-cli
mkdir -p ~/.oci
oci setup keys --key-name atm10_oci_api_key --output-dir ~/.oci
```

Then:

```bash
cd atm10-space-server/terraform/oci
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- Set `region`.
- Set `tenancy_ocid`.
- Set `user_ocid`.
- Set `compartment_ocid`.
- Set `fingerprint`.
- Set `ssh_cidr_blocks` to your public IP as `x.x.x.x/32`.
- Set `minecraft_whitelist` to the Minecraft account names allowed to join.
- Keep `allowed_minecraft_cidr_blocks = ["0.0.0.0/0"]` unless you only want specific players/IPs.

Deploy:

```bash
tofu init
tofu apply
```

If Oracle reports no A1 capacity in the selected availability domain, change `availability_domain_index` to `1` or `2` and rerun `tofu apply`.

When OpenTofu finishes, it prints the server IP and `IP:25565` address. First boot can take 10-20 minutes because ATM10 server files are large.

Watch startup logs:

```bash
ssh ubuntu@SERVER_IP 'sudo journalctl -u atm10 -f'
```

Restart the server:

```bash
ssh ubuntu@SERVER_IP 'sudo systemctl restart atm10'
```

Stop the server:

```bash
ssh ubuntu@SERVER_IP 'sudo systemctl stop atm10'
```

## AWS Deploy

Install Terraform and configure AWS credentials first:

```bash
aws configure
```

Then:

```bash
cd atm10-space-server/terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- Set `ssh_public_key_path`.
- Set `ssh_cidr_blocks` to your public IP as `x.x.x.x/32`.
- Keep `allowed_minecraft_cidr_blocks = ["0.0.0.0/0"]` unless you only want specific players/IPs.

Deploy:

```bash
terraform init
terraform apply
```

When Terraform finishes, it prints the server IP and `IP:25565` address. First boot can take 10-20 minutes because ATM10 server files are large.

Watch startup logs:

```bash
ssh ubuntu@SERVER_IP 'sudo journalctl -u atm10 -f'
```

Restart the server:

```bash
ssh ubuntu@SERVER_IP 'sudo systemctl restart atm10'
```

Stop the server:

```bash
ssh ubuntu@SERVER_IP 'sudo systemctl stop atm10'
```

## Client Setup

Every player needs the same client modpack:

1. Install **All the Mods 10 - ATM10 version 7.0** in CurseForge, Prism, or another launcher.
2. Add the same extra space jars that the server installed.

After AWS deploy, the exact added jars are stored on the server in `/opt/atm10/space-mods`. Pull them locally:

```bash
mkdir -p client-mods
scp ubuntu@SERVER_IP:'/opt/atm10/space-mods/*.jar' client-mods/
```

Then copy those jars into the client ATM10 instance's `mods` folder.

You can also download a fresh compatible set locally:

```bash
./atm10-space-server/scripts/download-space-mods.sh ./client-mods
```

The `scp` method is better after deployment because it guarantees the client jars match the server exactly.

## Minecraft Whitelist

The server is configured with:

- `online-mode=true`
- `white-list=true`
- `enforce-whitelist=true`

Set the allowed Minecraft accounts before deploy:

```hcl
minecraft_whitelist = [
  "PlayerOne",
  "PlayerTwo",
]
```

During provisioning, the script resolves those names to Mojang UUIDs and writes `whitelist.json`. If `minecraft_whitelist` is empty, the whitelist is still enforced, so nobody can join until the list is updated.

To update the whitelist after deploy:

```bash
ssh ubuntu@SERVER_IP 'sudo MINECRAFT_WHITELIST="PlayerOne,PlayerTwo,PlayerThree" /usr/local/sbin/provision-atm10.sh'
```

## Server Files

The provisioner installs:

- ATM10 `ServerFiles-7.0.zip`
- Java 21
- A systemd service named `atm10`
- Server properties tuned for a large modpack
- A `/opt/atm10/space-mods.lock` file listing the extra space mods it added

The world lives in `/opt/atm10/world`.

## Updating Later

For modded servers, take a backup before changing versions:

```bash
ssh ubuntu@SERVER_IP 'sudo systemctl stop atm10 && sudo tar -C /opt/atm10 -czf /opt/atm10/backups/world-before-update.tgz world && sudo systemctl start atm10'
```

Then update one thing at a time:

- ATM10 server pack version
- Stellaris/dependencies
- Client pack

All players must match the server.
