#!/bin/bash

set -e

# Install NodeJS package repo - https://deb.nodesource.com/
curl -fsSL https://deb.nodesource.com/setup_22.x | bash

# Install PostgreSQL package repo
# From https://www.linuxtechi.com/how-to-install-postgresql-on-ubuntu/
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
curl -qo /etc/apt/trusted.gpg.d/pgdg.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc

apt -y install nodejs postgresql-client

useradd -m -s /bin/bash nodeapp

mkdir -p /opt/nodeapp
chown nodeapp:nodeapp /opt/nodeapp

# START RUN COMMANDS AS USER nodeapp
su - nodeapp << EOF
cd /opt/nodeapp
git clone -b ${git_branch} https://${github_token}@github.com/${github_repo} .
npm install
EOF
# END RUN COMMANDS AS USER nodeapp

until pg_isready -U ${db_username} -h ${db_host}; do
	sleep 5
done

# Loading the SQL files is done here because the piping with sort
# in the heredoc used with the `su - nodeapp` doesn't work.
export PGPASSWORD="${db_password}"
for sql_file in $(find /opt/nodeapp/sys/sql/schema/*.sql | sort); do
	echo "Loading SQL file $sql_file..."
	psql -h ${db_host} -U ${db_username} -d ${db_name} -f "$sql_file"
done

# START RUN COMMANDS AS USER nodeapp
su - nodeapp << EOF
cd /opt/nodeapp
export DATABASE_URL=postgresql://${db_username}:${db_password}@${db_host}:5432/${db_name}
npm run build
EOF
# END RUN COMMANDS AS USER nodeapp

# Create systemd service for the Node.js app
cat > /etc/systemd/system/nodeapp.service << EOF
[Unit]
Description=Node.js Application
After=network.target

[Service]
Type=simple
User=nodeapp
WorkingDirectory=/opt/nodeapp
Environment=NODE_ENV=production
Environment=DATABASE_URL=postgresql://${db_username}:${db_password}@${db_host}:5432/${db_name}
ExecStart=/usr/bin/npm run start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable --now nodeapp

# Update all packages including (possibly) the kernel
#apt -y update
#apt -y full-upgrade

# Reboot to get the new kernel restart all systems
#reboot
