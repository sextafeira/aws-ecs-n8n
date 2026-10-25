ARG N8N_VERSION=2.44.6
FROM ghcr.io/n8n-io/n8n:${N8N_VERSION}
ADD --chown=node:node https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /opt/certs/global-bundle.pem
