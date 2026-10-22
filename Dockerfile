ARG N8N_VERSION
FROM docker.n8n.io/n8nio/n8n:${N8N_VERSION}
ADD --chown=node:node https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /opt/certs/global-bundle.pem
