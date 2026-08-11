# --- build: compila TypeScript e gera o Prisma Client ---
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npx prisma generate
RUN npm run build

# --- production: so o necessario pra rodar ---
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
COPY prisma ./prisma
RUN npm ci --omit=dev

COPY --from=build /app/dist ./dist

EXPOSE 3000

# prisma migrate deploy aplica migrations pendentes antes de subir a API --
# seguro rodar a cada deploy, so aplica o que ainda nao foi aplicado.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
