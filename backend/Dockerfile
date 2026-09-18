FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm install -g typescript ts-node
EXPOSE 80
CMD ["ts-node", "src/index.ts"]
