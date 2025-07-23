# ---- 1️⃣ build stage (installs deps) ----
FROM node:22-alpine AS base
WORKDIR /app

# Install only the production dependencies
COPY package*.json ./
RUN npm ci --omit=dev

# ---- 2️⃣ copy source & run ----
COPY . .
EXPOSE 8080               
CMD ["node", "app.js"]  