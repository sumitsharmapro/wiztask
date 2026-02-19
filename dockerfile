FROM node:18-slim
WORKDIR /app
RUN echo "Sumit Sharma @ Wiz" > /wizexercise.txt
COPY package.json .
RUN npm install
COPY app.js .
EXPOSE 8080
CMD ["node", "app.js"]
