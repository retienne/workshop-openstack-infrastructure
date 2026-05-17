# Modern Database Workshop - OpenStack Infrastructure

This repository contains the Infrastructure-as-Code (Terraform & Ansible) to provision and configure workshop environments on **any OpenStack cloud provider**.

This project provides a complete lifecycle for running workshop repositories originally authored by [Guido Schmutz (gschmutz)](https://github.com/gschmutz), such as:
- [modern-database-workshop](https://github.com/gschmutz/modern-database-workshop)
- [bigdata-spark-workshop](https://github.com/gschmutz/bigdata-spark-workshop)

## Why OpenStack?

While the original workshops were designed for AWS Lightsail, deploying on an OpenStack provider (such as [**Infomaniak Public Cloud**](https://www.infomaniak.com/en/hosting/public-cloud), which we use as a prime example here) offers several advantages:

- **Cost-Effective**: OpenStack instances on providers like Infomaniak often offer significantly more resources for a lower price than standard hyperscaler VMs.
- **Supporting Local Infrastructure**: Utilizing a European provider helps support regional IT ecosystems, offering a robust alternative to relying solely on major global cloud providers.
- **Broadening Skillsets**: It's valuable to understand how to deploy and manage infrastructure across different types of clouds. Working with OpenStack provides excellent hands-on experience beyond the standard AWS ecosystem.
- **Fewer Clicks**: This automated Terraform/Ansible workflow lets you spin up, pause, or tear down an entire environment instantly from the CLI, bypassing cumbersome web consoles.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
- [OpenStack CLI Client](https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html) (Optional, for managing OpenStack via CLI)
- **OpenStack Project Setup (e.g., Infomaniak)**:
  1. Create a Public Cloud project in your cloud provider's manager.
  2. Navigate to your OpenStack project's web console (Horizon).
  3. Click on your user profile at the top right, then select **OpenStack RC File v3**.
  4. Save this file as `openrc.sh` in the root of this repository.
- Source your OpenStack RC file containing your `OS_*` environment variables before running any commands: `source openrc.sh`

## Configuration

All environment variables are centralized in `ansible/group_vars/all.yml`. This file acts as the single source of truth for both Terraform and Ansible.

**Key Variables to Edit:**
- `workshop_password`: The password to set for the `ubuntu` user (ensure you change this from the default for production use!).
- `openstack_flavor`: The OpenStack flavor for the VM.
- `openstack_image`: The OpenStack image (e.g., "Ubuntu 24.04 LTS Noble Numbat").
- `openstack_keypair`: The name of the SSH keypair in your OpenStack project to inject into the VM for initial Ansible connectivity.
- `platys_minio_aistor_license`: If you are running the `bigdata-spark-workshop`, you must provide a valid AIStor license string here.

> [!TIP]
> **Finding the exact OS image string:**
> If you are unsure of the exact image name available in your OpenStack project, you can run the following command to list all available Ubuntu images:
> ```bash
> openstack image list --public | grep -i ubuntu
> ```

## Deployment

To deploy the environment:

1. Ensure your OpenStack RC file is sourced (`source openrc.sh`).
2. Edit `ansible/group_vars/all.yml` with your desired configuration.
3. Run the interactive deployment command:
   ```bash
   make up
   ```
   *The script will interactively ask you which workshop repository you want to deploy and which docker-compose environment folder to start.*

### Lifecycle Management

You can also run individual lifecycle commands:
- `make setup`: Only provision infrastructure and configure the base OS.
- `make start`: Interactively select and start a docker-compose environment (checks for and prompts to stop running environments first).
- `make stop`: Interactively select and stop a currently running docker-compose environment.
- `make connect`: SSH directly into the provisioned machine.
- `make open`: Open the workshop landing page in your local web browser.

### Day-to-Day VM Lifecycle

To save compute costs while retaining your disk state, you can pause the VM when the workshop is not active:

- `make pause`: Stops the OpenStack VM compute billing but retains the disk. This saves time on the next start.
- `make unpause`: Starts the paused VM back up.
- `make status`: Shows the current power state of the VM and lists all running Docker containers (with a fallback if the VM is paused).

### Ephemeral Deployment (Autodestruct)

If you are running a workshop and want to ensure you don't accidentally leave the environment running and accumulating costs, you can schedule it for automatic destruction:

- `make autodestroy-timer TTL=4h`: Schedules the infrastructure to be destroyed in 4 hours, or when you shut down/logout of your local machine.
- `make autodestroy-on-shutdown`: Schedules the infrastructure to self-destruct only when your local machine shuts down or logs out.
- `make autodestroy-status`: View how much time is left until self-destruction.
- `make autodestroy-cancel`: Cancel the scheduled destruction immediately.

> [!WARNING]
> These autodestroy features utilize local `systemd-run` timers. Your local Linux machine must be running systemd for this feature to work.

## Teardown

To completely destroy the infrastructure and stop billing:

```bash
make destroy
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
