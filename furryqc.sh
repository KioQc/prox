#!/bin/bash
# Helper script Proxmox VE – Wplace API Overlay

# VARIABLES À MODIFIER
DOMAIN="wplace.furryqc.net"   # ton domaine
EMAIL="kioqcpay@gmail.com"  # pour Let's Encrypt

# Update & dépendances
apt update && apt upgrade -y
apt install -y curl git build-essential ufw nginx certbot python3-certbot-nginx

# Installer Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g pm2

# Créer dossier serveur
mkdir -p /opt/wplace-api
cd /opt/wplace-api
npm init -y
npm install express cors body-parser shortid

# Créer server.js
cat > /opt/wplace-api/server.js << 'EOF'
const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const fs = require("fs");
const path = require("path");
const shortid = require("shortid");

const app = express();
const PORT = 3000;
const DATA_FILE = path.join(__dirname, "overlays.json");

app.use(cors());
app.use(bodyParser.json());

let overlays = {};
if(fs.existsSync(DATA_FILE)){
  overlays = JSON.parse(fs.readFileSync(DATA_FILE));
}

app.post("/api/save", (req,res)=>{
  const {image,x,y,zoom,opacity}=req.body;
  if(!image) return res.status(400).json({error:"Image obligatoire"});
  const id = shortid.generate();
  overlays[id] = {image,x,y,zoom,opacity};
  fs.writeFileSync(DATA_FILE,JSON.stringify(overlays,null,2));
  res.json({id});
});

app.get("/api/get/:id",(req,res)=>{
  const data = overlays[req.params.id];
  if(!data) return res.status(404).json({error:"ID non trouvé"});
  res.json(data);
});

app.listen(PORT,()=>console.log(`Server running on port ${PORT}`));
EOF

# Lancer le serveur via PM2
pm2 start /opt/wplace-api/server.js --name wplace-api
pm2 save
pm2 startup systemd

# Configurer firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw enable

# Configurer Nginx
cat > /etc/nginx/sites-available/wplace-api << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -s /etc/nginx/sites-available/wplace-api /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Installer SSL avec Let's Encrypt
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

echo "✅ Installation terminée !"
echo "Serveur Node.js : http://127.0.0.1:3000"
echo "Domaine accessible via HTTPS : https://$DOMAIN"
