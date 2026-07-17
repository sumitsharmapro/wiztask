FROM node:18-slim
WORKDIR /app
RUN echo "Wiz (L) Google" > /wizexercise.txt
COPY package.json .
RUN npm install
COPY app.js .
EXPOSE 8080
CMD ["node", "app.js"]
