# Dockerfile para Frontend
FROM nginx:alpine

# Copia todos os arquivos estáticos
COPY . /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
