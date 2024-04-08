Usage
-----

Create the necessary directories and download the installation script:

```bash
mkdir -p /storage/scripts/ && curl -s https://raw.githubusercontent.com/SiviumSolutions/teltonika-data-sender/main/install.sh -o /storage/scripts/install.sh && chmod +x /storage/scripts/install.sh && /storage/scripts/install.sh <NODE_URL> <UUID> <TOKEN>
